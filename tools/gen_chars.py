#!/usr/bin/env python3
"""
SPLASH TRIAL: Murder at Yuzu Springs -- character portrait generator.

Writes art/chars/<id>_<expr>.svg (480x600, transparent) for the 15 capybara guests
plus Warden Snapjaw, in 5 expressions each (normal happy shock angry sad).

Everything is built from one shared parametric capybara bust (head, ears, snout,
eyes, whiskers, shoulders) + per-character fur colours, outfits, hats and props,
and one shared expression system (eyes / brows / mouth / blush, sweat, tears,
anger marks, gloom lines, sparkles).  Snapjaw is a separate robotic-caiman bust.

Only plain SVG 1.1 shapes are emitted (path/circle/ellipse/rect/g/defs/gradients/
clipPath, opacity, transforms) -- no text, filters, images or CSS -- so Godot's
ThorVG rasterizer renders them exactly.

Usage:
    python3 tools/gen_chars.py                 # all 80 portraits
    python3 tools/gen_chars.py mochi wisp      # only some characters
    python3 tools/gen_chars.py --check         # validate existing files
"""
import math
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUTDIR = os.path.join(ROOT, 'art', 'chars')
EXPRS = ['normal', 'happy', 'shock', 'angry', 'sad']
IDS = ['mochi', 'coco', 'wisp', 'bruno', 'lulu', 'pepper', 'duchess', 'bramble',
       'nibs', 'zuzu', 'reginald', 'grub', 'tumble', 'marigold', 'fennel', 'snapjaw']

OUT = '#2a1a10'          # outline colour
SW = 6.5                 # main outline width
SIL = 8.5                # heavier silhouette outline (head + body)
WHITE = '#ffffff'

# trial-night lighting palette: warm key light from the top-left, hot-spring aqua bounce/rim
# light from the pool below-right (coral-red when angry), cool night-violet cel shadows.
AQUA = '#3ee0d0'
CORAL = '#ff4f6d'
GLOOM = '#1d0b3a'        # deep violet shock gloom
NIGHT_SH = '#1a0c2e'     # hard cast-shadow tone on clothes
SAD_BLUE = '#3d48b4'

# ============================================================================ helpers


def n(v):
	"""compact number formatting"""
	s = '%.1f' % v
	if s == '-0.0':
		s = '0.0'
	if s.endswith('.0'):
		s = s[:-2]
	return s


def pt(p):
	return n(p[0]) + ',' + n(p[1])


def _style(fill, st, sw, op, extra):
	a = ' fill="%s"' % (fill if fill else 'none')
	if st:
		a += ' stroke="%s" stroke-width="%s" stroke-linejoin="round" stroke-linecap="round"' % (st, n(sw))
	if op is not None and op < 0.999:
		a += ' opacity="%.2f"' % op
	return a + extra


def P(d, fill=None, st=OUT, sw=SW, op=None, extra=''):
	return '<path d="%s"%s/>' % (d, _style(fill, st, sw, op, extra))


def C(x, y, r, fill=None, st=OUT, sw=SW, op=None, extra=''):
	return '<circle cx="%s" cy="%s" r="%s"%s/>' % (n(x), n(y), n(r), _style(fill, st, sw, op, extra))


def E(x, y, rx, ry, fill=None, st=OUT, sw=SW, op=None, extra=''):
	return '<ellipse cx="%s" cy="%s" rx="%s" ry="%s"%s/>' % (n(x), n(y), n(rx), n(ry), _style(fill, st, sw, op, extra))


def R(x, y, w, h, rx=0, fill=None, st=OUT, sw=SW, op=None, extra=''):
	r = ' rx="%s"' % n(rx) if rx else ''
	return '<rect x="%s" y="%s" width="%s" height="%s"%s%s/>' % (n(x), n(y), n(w), n(h), r, _style(fill, st, sw, op, extra))


def G(inner, tf=None, clip=None, op=None):
	a = ''
	if tf:
		a += ' transform="%s"' % tf
	if clip:
		a += ' clip-path="url(#%s)"' % clip
	if op is not None and op < 0.999:
		a += ' opacity="%.2f"' % op
	return '<g%s>%s</g>' % (a, inner)


def rot(a, x, y):
	return 'rotate(%s %s %s)' % (n(a), n(x), n(y))


def line(pts):
	return 'M' + ' L'.join(pt(p) for p in pts)


def poly(pts):
	return line(pts) + 'Z'


def smooth(pts, closed=True, k=1.0):
	"""Catmull-Rom spline through pts -> cubic bezier path data."""
	m = len(pts)
	if closed:
		get = lambda i: pts[i % m]
		segs = m
	else:
		get = lambda i: pts[min(max(i, 0), m - 1)]
		segs = m - 1
	d = 'M' + pt(pts[0])
	for i in range(segs):
		p0, p1, p2, p3 = get(i - 1), get(i), get(i + 1), get(i + 2)
		c1 = (p1[0] + (p2[0] - p0[0]) * k / 6.0, p1[1] + (p2[1] - p0[1]) * k / 6.0)
		c2 = (p2[0] - (p3[0] - p1[0]) * k / 6.0, p2[1] - (p3[1] - p1[1]) * k / 6.0)
		d += 'C' + pt(c1) + ' ' + pt(c2) + ' ' + pt(p2)
	if closed:
		d += 'Z'
	return d


def sample_smooth(pts, per=12, closed=False):
	"""sample points along a Catmull-Rom curve (for placing teeth, pearls, stars...)"""
	m = len(pts)
	get = (lambda i: pts[i % m]) if closed else (lambda i: pts[min(max(i, 0), m - 1)])
	segs = m if closed else m - 1
	out = []
	for i in range(segs):
		p0, p1, p2, p3 = get(i - 1), get(i), get(i + 1), get(i + 2)
		for s in range(per):
			t = s / float(per)
			t2, t3 = t * t, t * t * t
			x = 0.5 * ((2 * p1[0]) + (-p0[0] + p2[0]) * t + (2 * p0[0] - 5 * p1[0] + 4 * p2[0] - p3[0]) * t2 + (-p0[0] + 3 * p1[0] - 3 * p2[0] + p3[0]) * t3)
			y = 0.5 * ((2 * p1[1]) + (-p0[1] + p2[1]) * t + (2 * p0[1] - 5 * p1[1] + 4 * p2[1] - p3[1]) * t2 + (-p0[1] + 3 * p1[1] - 3 * p2[1] + p3[1]) * t3)
			out.append((x, y))
	if not closed:
		out.append(pts[-1])
	return out


def resample(pts, count):
	"""evenly spaced points along a polyline"""
	seg = [0.0]
	for i in range(1, len(pts)):
		seg.append(seg[-1] + math.hypot(pts[i][0] - pts[i - 1][0], pts[i][1] - pts[i - 1][1]))
	total = seg[-1]
	out = []
	j = 0
	for k in range(count):
		t = total * k / float(max(count - 1, 1))
		while j < len(seg) - 2 and seg[j + 1] < t:
			j += 1
		span = seg[j + 1] - seg[j] or 1.0
		u = (t - seg[j]) / span
		a, b = pts[j], pts[j + 1]
		out.append((a[0] + (b[0] - a[0]) * u, a[1] + (b[1] - a[1]) * u))
	return out


def sym(half, cx=240):
	"""half outline from top-centre to bottom-centre along the right side -> full loop"""
	left = [(2 * cx - x, y) for (x, y) in reversed(half[1:-1])]
	return list(half) + left


def mirror_d(pts, cx=240):
	return [(2 * cx - x, y) for (x, y) in pts]


def star(cx, cy, r, inner=0.45, points=5, a0=-90.0):
	pts = []
	for i in range(points * 2):
		rr = r if i % 2 == 0 else r * inner
		a = math.radians(a0 + i * 180.0 / points)
		pts.append((cx + rr * math.cos(a), cy + rr * math.sin(a)))
	return poly(pts)


def sparkle(cx, cy, r, ry=None):
	"""4-point concave twinkle"""
	ry = ry or r
	return ('M%s Q%s %s Q%s %s Q%s %s Q%s %sZ' % (
		pt((cx, cy - ry)), pt((cx, cy)), pt((cx + r, cy)), pt((cx, cy)), pt((cx, cy + ry)),
		pt((cx, cy)), pt((cx - r, cy)), pt((cx, cy)), pt((cx, cy - ry))))


def drop(cx, cy, s):
	"""water drop pointing up, (cx,cy) = centre of the round part, s = radius"""
	return ('M%s C%s %s %s C%s %s %s C%s %s %s C%s %s %sZ' % (
		pt((cx, cy - s * 2.1)),
		pt((cx + s * 0.35, cy - s * 1.4)), pt((cx + s, cy - s * 0.6)), pt((cx + s, cy + s * 0.05)),
		pt((cx + s, cy + s * 0.65)), pt((cx + s * 0.55, cy + s)), pt((cx, cy + s)),
		pt((cx - s * 0.55, cy + s)), pt((cx - s, cy + s * 0.65)), pt((cx - s, cy + s * 0.05)),
		pt((cx - s, cy - s * 0.6)), pt((cx - s * 0.35, cy - s * 1.4)), pt((cx, cy - s * 2.1))))


def heart(cx, cy, s):
	return ('M%s C%s %s %s C%s %s %s C%s %s %s C%s %s %sZ' % (
		pt((cx, cy + s)),
		pt((cx - s * 1.3, cy + s * 0.1)), pt((cx - s * 1.1, cy - s * 1.0)), pt((cx - s * 0.5, cy - s * 0.9)),
		pt((cx - s * 0.15, cy - s * 0.85)), pt((cx, cy - s * 0.5)), pt((cx, cy - s * 0.35)),
		pt((cx, cy - s * 0.5)), pt((cx + s * 0.15, cy - s * 0.85)), pt((cx + s * 0.5, cy - s * 0.9)),
		pt((cx + s * 1.1, cy - s * 1.0)), pt((cx + s * 1.3, cy + s * 0.1)), pt((cx, cy + s))))


def mix(a, b, t):
	a = a.lstrip('#')
	b = b.lstrip('#')
	ca = [int(a[i:i + 2], 16) for i in (0, 2, 4)]
	cb = [int(b[i:i + 2], 16) for i in (0, 2, 4)]
	return '#' + ''.join('%02x' % int(round(ca[i] + (cb[i] - ca[i]) * t)) for i in range(3))


def darker(c, t=0.25):
	return mix(c, '#1a0e08', t)


def lighter(c, t=0.3):
	return mix(c, '#ffffff', t)


class Doc:
	"""one SVG document: collects defs (gradients, clip paths) + body markup"""

	def __init__(self):
		self.defs = []
		self.k = 0

	def uid(self, p):
		self.k += 1
		return '%s%d' % (p, self.k)

	def clip(self, d, tf=None):
		i = self.uid('k')
		t = ' transform="%s"' % tf if tf else ''
		self.defs.append('<clipPath id="%s"><path d="%s"%s/></clipPath>' % (i, d, t))
		return i

	def lin(self, stops, x1=0, y1=0, x2=0, y2=1, user=None):
		i = self.uid('l')
		u = ''
		if user:
			u = ' gradientUnits="userSpaceOnUse"'
			x1, y1, x2, y2 = user
		s = ''.join('<stop offset="%s" stop-color="%s"%s/>' % (
			n(o) if o in (0, 1) else '%.2f' % o, c, (' stop-opacity="%.2f"' % a) if a < 1 else '')
			for (o, c, a) in [(st + (1.0,)) if len(st) == 2 else st for st in stops])
		self.defs.append('<linearGradient id="%s" x1="%s" y1="%s" x2="%s" y2="%s"%s>%s</linearGradient>' % (
			i, n(x1), n(y1), n(x2), n(y2), u, s))
		return 'url(#%s)' % i

	def rad(self, stops, cx=0.5, cy=0.5, r=0.5, fx=None, fy=None, user=False):
		i = self.uid('r')
		u = ' gradientUnits="userSpaceOnUse"' if user else ''
		f = ''
		if fx is not None:
			f = ' fx="%s" fy="%s"' % (n(fx) if user else '%.2f' % fx, n(fy) if user else '%.2f' % fy)
		fmt = n if user else (lambda v: '%.2f' % v)
		s = ''.join('<stop offset="%s" stop-color="%s"%s/>' % (
			n(o) if o in (0, 1) else '%.2f' % o, c, (' stop-opacity="%.2f"' % a) if a < 1 else '')
			for (o, c, a) in [(st + (1.0,)) if len(st) == 2 else st for st in stops])
		self.defs.append('<radialGradient id="%s" cx="%s" cy="%s" r="%s"%s%s>%s</radialGradient>' % (
			i, fmt(cx), fmt(cy), fmt(r), f, u, s))
		return 'url(#%s)' % i

	def render(self, body):
		return ('<svg xmlns="http://www.w3.org/2000/svg" width="480" height="600" viewBox="0 0 480 600">'
			'<defs>%s</defs>%s</svg>\n') % (''.join(self.defs), body)


# ============================================================================ capybara anatomy
# Canonical head space: centre x=240, crown y~74, chin y~341.  The whole head group is
# transformed per character (scale) and per expression (tilt / bob).

EYE_Y = 178
EYE_SCALE = 1.08
EYE_DX = 64
MOUTH_Y = 258

SHIFT = 12   # whole bust moved down a little so tall hats fit the 600px canvas

POSE = {  # tilt degrees, vertical bob
	'normal': (0.0, 0.0),
	'happy': (-3.0, -4.0),
	'shock': (0.0, -6.0),
	'angry': (2.5, 3.0),
	'sad': (3.5, 9.0),
}


def head_pts(c):
	ch = c.get('cheek', 0)
	half = [(240, 72), (300, 74), (344, 85), (364, 114), (371 + ch * 0.3, 170),
		(378 + ch, 232), (374 + ch * 0.8, 284), (340 + ch * 0.5, 322), (240, 334)]
	return sym(half)


# the broad blunt capybara snout: the whole lower face
MUZZLE_PTS = sym([(240, 200), (288, 202), (322, 216), (344, 250), (352, 292), (334, 330), (240, 344)])
# the long nose bridge running from between the eyes down to the nose
BRIDGE_PTS = sym([(240, 132), (262, 136), (276, 170), (284, 214), (240, 222)])


def ellipse_d(x, y, rx, ry):
	return 'M%s A%s %s 0 1 0 %s A%s %s 0 1 0 %sZ' % (pt((x - rx, y)), n(rx), n(ry), pt((x + rx, y)), n(rx), n(ry), pt((x - rx, y)))


ANGRY_RIM = mix(CORAL, '#ff7a3a', 0.3)   # coral-red, pushed a little warmer so it never reads pink


def rim_col(e):
	return ANGRY_RIM if e == 'angry' else AQUA


def rim_grad(d, e, p0, p1, peak, start=0.4):
	"""rim-light paint: transparent on the lit (top-left) side, rising to `peak` on the shadow side"""
	col = rim_col(e)
	return d.lin([(0, col, 0.0), (start, col, 0.0), (min(start + 0.38, 0.95), col, peak), (1, col, peak)], user=(p0[0], p0[1], p1[0], p1[1]))


def cel_shade(c, e):
	"""the one hard cel-shadow tone: a little deeper and cooler (night violet) than the base shade"""
	if e == 'sad':
		return mix(c['shade'], '#1e3470', 0.2)
	return mix(c['shade'], '#2a1240', {'shock': 0.3, 'angry': 0.22}.get(e, 0.13))


def draw_ears(d, c, e='normal'):
	if c.get('ears') is False:
		return ''
	dx, y, tilt = c.get('ears', (98, 78, 18))
	s = ''
	for side in (-1, 1):
		x = 240 + side * dx
		ear = E(x, y, 19, 21, fill=cel_shade(c, e), st=None)
		k = d.clip(ellipse_d(x, y, 19, 21))
		ear += G(E(x - 5, y - 4, 19, 21, fill=c['fur'], st=None), clip=k)
		if side == 1:
			# pool light catching the shadow-side ear
			ear += G(P('M%s A19 21 0 0 1 %s' % (pt((x + 2, y - 21)), pt((x + 10, y + 18))), st=rim_col(e), sw=15,
				op=0.9 if e == 'angry' else 0.65), clip=k)
		ear += E(x, y, 19, 21, st=OUT, sw=SW)
		ear += E(x + side * 1.5, y + 3, 9.5, 11, fill=c['inner'], st=None)
		ear += E(x - side * 5, y - 7, 5, 5, fill=WHITE, st=None, op=0.2)
		s += G(ear, tf=rot(side * tilt, x, y))
	return s


def draw_head_base(d, c, e):
	hp = smooth(head_pts(c))
	hc = d.clip(hp)
	s = P(hp, fill=cel_shade(c, e), st=None)
	ox, oy = {'shock': (-22, -16), 'angry': (-21, -15)}.get(e, (-19, -14))
	lit = P(hp, fill=c['fur'], st=None, extra=' transform="translate(%d %d)"' % (ox, oy))
	glow = E(196, 116, 46, 22, fill=WHITE, st=None, op=0.24 if e == 'happy' else 0.16, extra=' transform="%s"' % rot(-14, 196, 116))
	s += G(lit + glow + c.get('fur_marks', lambda d, c: '')(d, c), clip=hc)
	return s, hp, hc


def draw_head_rim(d, c, e, hp, hc):
	"""thin rim light hugging the head silhouette on the shadow side (drawn over fur + muzzle, under the features)"""
	if e == 'angry':
		g = rim_grad(d, e, (150, 100), (370, 330), 1.0, 0.36)
		return G(P(hp, st=g, sw=25), clip=hc)
	g = rim_grad(d, e, (150, 100), (360, 330), 0.78)
	return G(P(hp, st=g, sw=18), clip=hc)


def draw_muzzle(d, c, hc, e='normal'):
	mp = smooth(MUZZLE_PTS)
	mc = d.clip(mp)
	shade = mix(c['muzzle'], cel_shade(c, e), 0.62)
	inner = P(mp, fill=shade, st=None) + P(mp, fill=c['muzzle'], st=None, extra=' transform="translate(-12 -10)"')
	bridge = P(smooth(BRIDGE_PTS), fill=lighter(c['fur'], 0.16), st=None, op=0.75)
	s = G(bridge, clip=hc)
	s += G(P(mp, fill=c['muzzle'], st=None) + G(inner, clip=mc), clip=hc)
	# soft upper snout contour
	s += P('M%s C%s %s %s' % (pt((150, 268)), pt((152, 226)), pt((186, 202)), pt((240, 200))), st=OUT, sw=3.5, op=0.45)
	s += P('M%s C%s %s %s' % (pt((330, 268)), pt((328, 226)), pt((294, 202)), pt((240, 200))), st=OUT, sw=3.5, op=0.45)
	return s


def draw_nose(d, c):
	np_ = smooth(sym([(240, 220), (270, 220), (290, 226), (291, 238), (276, 247), (256, 250), (240, 247)]))
	s = P(np_, fill=c.get('nose', '#4a2b1b'), st=OUT, sw=3.5)
	s += E(228, 227, 15, 4.2, fill=WHITE, st=None, op=0.5, extra=' transform="%s"' % rot(-5, 228, 227))
	for side in (-1, 1):
		x = 240 + side * 31
		s += E(x, 237, 7, 3.4, fill='#120804', st=None, extra=' transform="%s"' % rot(side * 34, x, 237))
	s += P('M240,247 L240,%s' % n(MOUTH_Y + 1), st=OUT, sw=4)
	return s


def draw_whiskers(c):
	s = ''
	col = c.get('whisker', OUT)
	for side in (-1, 1):
		for (yy, dy, ln) in ((266, -6, 40), (282, 4, 38)):
			x0 = 240 + side * 96
			s += P('M%s Q%s %s' % (pt((x0, yy)), pt((x0 + side * ln * 0.5, yy + dy * 0.3 - 2)), pt((x0 + side * ln, yy + dy))),
				st=col, sw=3.2, op=0.85)
		for (xx, yy) in ((76, 268), (68, 282), (80, 292)):
			s += C(240 + side * xx, yy, 2.6, fill=darker(c['muzzle'], 0.45), st=None)
	return s


def draw_blush(c, e):
	s = ''
	op = c.get('blush_op', 0.28)
	col = c.get('blush', '#ff6f8c')
	if e == 'happy':
		op = max(op, 0.5)
	elif e == 'angry':
		col, op = '#ff4a3a', max(op, 0.32)
	elif e == 'shock':
		op = op * 0.5
	for side in (-1, 1):
		x = 240 + side * 100
		s += E(x, 226, 24, 13, fill=col, st=None, op=op)
		if e == 'happy' or c.get('blush_lines'):
			for k in (-1, 0, 1):
				xx = x + k * 9
				s += P('M%s L%s' % (pt((xx + 3, 220)), pt((xx - 3, 232))), st=WHITE if e != 'happy' else '#ff3f6e', sw=2.6, op=0.7)
	return s


# ---------------------------------------------------------------------------- eyes


def lid_line_y(cx, rx, side, y0, slant):
	"""returns function x->y for the lid line (inner corner = toward face centre)"""
	inner_x = cx - side * rx
	outer_x = cx + side * rx

	def f(x):
		t = (x - outer_x) / (inner_x - outer_x)
		return (y0 - slant) + t * (2 * slant)
	return f


def eye_open(d, c, cx, cy, rx, ry, side, lid, slant, e):
	s = ''
	iris = c.get('iris_fill')
	if not iris:
		iris = c['_irisgrad']
	core = E(cx, cy, rx, ry, fill=OUT, st=None)
	core += E(cx, cy + 2, rx - 4, ry - 4.5, fill=iris, st=None)
	pr = 0.42 if e != 'angry' else 0.3
	core += E(cx, cy + 4, (rx - 4) * pr * 1.1, (ry - 4) * pr * 1.1, fill='#140a05', st=None)
	# iris ring sparkle
	core += P('M%s Q%s %s' % (pt((cx - rx * 0.55, cy + ry * 0.45)), pt((cx, cy + ry * 0.85)), pt((cx + rx * 0.55, cy + ry * 0.45))),
		st=lighter(c['iris'], 0.45), sw=2.5, op=0.8)
	big = 1.25 if e == 'sad' else 1.0
	if c.get('star_eyes') and e in ('normal', 'happy'):
		core += P(sparkle(cx - rx * 0.28, cy - ry * 0.3, rx * 0.5, ry * 0.42), fill=WHITE, st=None)
	else:
		core += E(cx - rx * 0.3, cy - ry * 0.34, rx * 0.36 * big, ry * 0.3 * big, fill=WHITE, st=None)
	core += C(cx + rx * 0.36, cy + ry * 0.34, rx * 0.16 * big, fill=WHITE, st=None)
	if e == 'sad':
		core += E(cx, cy + ry * 0.62, rx * 0.8, ry * 0.3, fill='#a8e4ff', st=None, op=0.85)
	if lid > 0.001 or abs(slant) > 0.001:
		y0 = cy - ry + lid * 2 * ry
		f = lid_line_y(cx, rx, side, y0, slant)
		xa, xb = cx - rx - 12, cx + rx + 12
		clip = d.clip(poly([(xa, f(xa)), (xb, f(xb)), (xb, cy + ry + 20), (xa, cy + ry + 20)]))
		s += G(core, clip=clip)
		# lid line across the chord
		xs = [cx - rx + i * (2 * rx) / 40.0 for i in range(41)]
		inside = [x for x in xs if ((x - cx) / rx) ** 2 + ((f(x) - cy) / ry) ** 2 <= 1.0]
		if inside:
			x1, x2 = inside[0] - 3, inside[-1] + 3
			s += P('M%s L%s' % (pt((x1, f(x1))), pt((x2, f(x2)))), st=OUT, sw=6.5)
			top_outer = (x2, f(x2)) if side > 0 else (x1, f(x1))
		else:
			top_outer = (cx + side * rx * 0.8, cy - ry * 0.6)
	else:
		s += core
		top_outer = (cx + side * rx * 0.78, cy - ry * 0.62)
	if c.get('lashes'):
		ox, oy = top_outer
		cnt = c.get('lashes') if isinstance(c.get('lashes'), int) else 2
		for k in range(cnt):
			ang = math.radians(-20 - k * 22)
			ln = 12 - k * 1.5
			s += P('M%s L%s' % (pt((ox - side * 2, oy + 1)), pt((ox + side * ln * math.cos(ang), oy + ln * math.sin(ang) - 2))), st=OUT, sw=4.5)
	return s


def eye_happy(cx, cy, rx, ry, side):
	return P('M%s Q%s %s' % (pt((cx - rx - 1, cy + 7)), pt((cx, cy - ry * 1.05)), pt((cx + rx + 1, cy + 7))), st=OUT, sw=7.5)


def eye_shock(cx, cy, rx, ry, c=None):
	"""staring white eye with a shrunken pinprick pupil ringed in bright iris colour"""
	s = E(cx, cy - 1, rx * 1.1, ry * 1.12, fill=WHITE, st=OUT, sw=5.5)
	ring = lighter(c['iris'], 0.2) if c else '#7fd8ff'
	s += C(cx, cy + 1, max(7.0, rx * 0.4), fill=ring, st=OUT, sw=2.2)
	s += C(cx, cy + 1, max(3.2, rx * 0.17), fill=OUT, st=None)
	s += C(cx - 2.4, cy - 2, 1.7, fill=WHITE, st=None)
	return s


def draw_eyes(d, c, e):
	s = ''
	es = c.get('eye_scale', 1.0) * EYE_SCALE
	rx, ry = 19 * es, 24 * es
	for side in (-1, 1):
		cx, cy = 240 + side * EYE_DX, EYE_Y
		if e == 'happy':
			s += eye_happy(cx, cy, rx, ry, side)
			if c.get('lashes'):
				s += P('M%s L%s' % (pt((cx + side * (rx + 1), cy + 7)), pt((cx + side * (rx + 10), cy + 1))), st=OUT, sw=4.5)
		elif e == 'shock':
			s += eye_shock(cx, cy, rx, ry, c)
		else:
			lid, slant = c.get('lid', 0.0), c.get('lid_slant', 0.0)
			if e == 'angry':
				lid, slant = max(lid * 0.8, 0.26), 9.0
			elif e == 'sad':
				lid, slant = max(lid * 0.8, 0.22), -8.0
			s += eye_open(d, c, cx, cy, rx, ry, side, lid, slant, e)
	return s


# ---------------------------------------------------------------------------- brows

BROWS = {   # (outer dy, mid dy, inner dy) relative to base, inner = toward centre
	'normal': (3, -3, 1),
	'happy': (-4, -12, -7),
	'shock': (-14, -22, -15),
	'angry': (-7, 3, 15),
	'sad': (9, 0, -11),
}


def draw_brows(c, e):
	es = c.get('eye_scale', 1.0) * EYE_SCALE
	base = EYE_Y - 24 * es - 16 + c.get('brow_dy', 0)
	col = c.get('brow', darker(c['shade'], 0.55))
	w = c.get('brow_w', 8.5) + (1.5 if e == 'angry' else 0)
	s = ''
	for side in (-1, 1):
		cx = 240 + side * EYE_DX
		o, m, i = BROWS[e]
		if e == 'normal' and c.get('brow_raise') and side == 1:
			o, m, i = (-6, -14, -8)
		ins = 4 if e == 'angry' else 0
		po = (cx + side * 18, base + o)
		pm = (cx - side * 1, base + m)
		pi = (cx - side * (18 + ins), base + i)
		if c.get('bushy'):
			# big fluffy old-man brows
			col2 = c.get('brow', '#f4f1ea')
			pts = [(po[0] + side * 8, po[1] + 6), pm, (pi[0], pi[1])]
			lump = ''
			for k, p in enumerate(resample(sample_smooth(pts, 8), 5)):
				lump += C(p[0], p[1], 10 - k * 0.6, fill=col2, st=OUT, sw=3.5)
			for k, p in enumerate(resample(sample_smooth(pts, 8), 5)):
				lump += C(p[0], p[1], 8.3 - k * 0.6, fill=col2, st=None)
			s += lump
		else:
			s += P('M%s Q%s %s' % (pt(po), pt((pm[0], pm[1] * 2 - (po[1] + pi[1]) / 2.0)), pt(pi)), st=col, sw=w)
	return s


# ---------------------------------------------------------------------------- mouths

MOUTH_DARK = '#6e1f2b'
TONGUE = '#ff7d92'


def buck_teeth(y, clip):
	t = R(229.5, y - 2, 10, 13, rx=2.5, fill=WHITE, st=OUT, sw=2.2) + R(240.5, y - 2, 10, 13, rx=2.5, fill=WHITE, st=OUT, sw=2.2)
	return G(t, clip=clip)


def draw_mouth(d, c, e):
	y = MOUTH_Y
	style = c.get('mouth', 'w')
	s = ''
	if e == 'normal':
		if style == 'w':
			s = P('M%s C%s %s %s C%s %s %s' % (pt((219, y + 1)), pt((221, y + 11)), pt((237, y + 12)), pt((240, y + 2)),
				pt((243, y + 12)), pt((259, y + 11)), pt((261, y + 1))), st=OUT, sw=4.5)
		elif style == 'smile':
			s = P('M%s C%s %s %s' % (pt((212, y + 2)), pt((220, y + 26)), pt((260, y + 26)), pt((268, y + 2))), st=OUT, sw=5)
			s += P('M%s L%s M%s L%s' % (pt((208, y + 6)), pt((214, y)), pt((272, y + 6)), pt((266, y))), st=OUT, sw=4)
		elif style == 'smirk':
			s = P('M%s C%s %s %s' % (pt((222, y + 10)), pt((236, y + 16)), pt((256, y + 14)), pt((266, y + 1))), st=OUT, sw=4.8)
			s += P('M%s C%s %s %s' % (pt((219, y + 1)), pt((221, y + 8)), pt((236, y + 10)), pt((240, y + 2))), st=OUT, sw=4)
		elif style == 'flat':
			s = P('M%s L%s' % (pt((224, y + 12)), pt((256, y + 12))), st=OUT, sw=4.8)
			s += P('M%s C%s %s %s C%s %s %s' % (pt((228, y + 1)), pt((230, y + 6)), pt((238, y + 6)), pt((240, y + 2)),
				pt((242, y + 6)), pt((250, y + 6)), pt((252, y + 1))), st=OUT, sw=3.5)
		elif style == 'grin':
			mp = 'M%s Q%s %s Q%s %s Z' % (pt((214, y + 2)), pt((240, y + 8)), pt((266, y + 2)), pt((240, y + 34)), pt((214, y + 2)))
			k = d.clip(mp)
			s = P(mp, fill=MOUTH_DARK, st=None) + G(E(240, y + 30, 16, 9, fill=TONGUE, st=None), clip=k) + buck_teeth(y + 4, k)
			s += P(mp, st=OUT, sw=4.5)
	elif e == 'happy':
		mp = 'M%s Q%s %s Q%s %s Q%s %s Z' % (pt((210, y + 1)), pt((240, y + 9)), pt((270, y + 1)),
			pt((268, y + 42)), pt((240, y + 44)), pt((212, y + 42)), pt((210, y + 1)))
		k = d.clip(mp)
		s = P(mp, fill=MOUTH_DARK, st=None)
		s += G(E(240, y + 42, 22, 14, fill=TONGUE, st=None), clip=k)
		s += buck_teeth(y + 5, k)
		s += P(mp, st=OUT, sw=4.8)
	elif e == 'shock':
		mp = smooth([(240, y + 3), (258, y + 10), (262, y + 30), (252, y + 48), (240, y + 51), (228, y + 48), (218, y + 30), (222, y + 10)])
		k = d.clip(mp)
		s = P(mp, fill=MOUTH_DARK, st=None)
		s += G(E(240, y + 50, 16, 10, fill=TONGUE, st=None), clip=k)
		s += buck_teeth(y + 6, k)
		s += P(mp, st=OUT, sw=4.8)
	elif e == 'angry':
		mp = 'M%s Q%s %s Q%s %s Q%s %s Q%s %s Z' % (pt((206, y + 8)), pt((206, y + 2)), pt((214, y + 2)), pt((240, y + 6)), pt((266, y + 2)),
			pt((274, y + 2)), pt((274, y + 8)), pt((272, y + 34)), pt((240, y + 36)))
		mp = smooth([(206, y + 6), (222, y + 1), (240, y + 5), (258, y + 1), (274, y + 6), (272, y + 24), (258, y + 33), (240, y + 34), (222, y + 33), (208, y + 24)])
		k = d.clip(mp)
		# clenched zig-zag fangs: a pointed upper row biting down over a pointed lower row
		teeth = P(mp, fill=MOUTH_DARK, st=None)
		up = [(200, y - 4)]
		for i, x in enumerate(range(206, 276, 10)):
			up += [(x, y - 4 if i == 0 else y + 2), (x + 5, y + 21 + (3 if 2 <= i <= 4 else 0))]
		up += [(276, y + 2), (280, y - 4)]
		lo = [(200, y + 40)]
		for i, x in enumerate(range(211, 271, 10)):
			lo += [(x, y + 34), (x + 5, y + 17)]
		lo += [(271, y + 34), (280, y + 40)]
		teeth += P(poly(lo), fill='#e9e4ec', st=OUT, sw=2.2) + P(poly(up), fill=WHITE, st=OUT, sw=2.2)
		s = G(teeth, clip=k) + P(mp, st=OUT, sw=5.2)
	elif e == 'sad':
		mp = smooth([(240, y + 14), (254, y + 16), (264, y + 25), (262, y + 30), (250, y + 26), (240, y + 25), (230, y + 26), (218, y + 30), (216, y + 25), (226, y + 16)])
		s = P(mp, fill=MOUTH_DARK, st=OUT, sw=4.5)
		s += P('M%s Q%s %s' % (pt((230, y + 19)), pt((240, y + 17)), pt((250, y + 19))), st=lighter(MOUTH_DARK, 0.3), sw=2.5, op=0.6)
	return s


# ---------------------------------------------------------------------------- FX


def fx_sweat(x, y, s=13):
	return (P(drop(x, y, s), fill='#c8eeff', st='#1f5fae', sw=3.8) + P(drop(x + s * 0.18, y + s * 0.2, s * 0.62), fill='#8fd3ff', st=None, op=0.55)
		+ E(x - s * 0.36, y - s * 0.12, s * 0.22, s * 0.4, fill=WHITE, st=None, op=0.95))


def fx_sweat_big(x, y):
	"""shock sweat: one big drop + a smaller one sliding down, with a little drip trail"""
	side = 1 if x > 240 else -1
	s = fx_sweat(x, y, 18)
	s += fx_sweat(x + side * 16, y + 58, 9)
	return s


def fx_anger(x, y, s=1.0):
	d = ''
	for (sx, sy) in ((-1, -1), (1, -1), (1, 1), (-1, 1)):
		a = (x + sx * 5 * s, y + sy * 17 * s)
		b = (x + sx * 5 * s, y + sy * 5 * s)
		cc = (x + sx * 17 * s, y + sy * 5 * s)
		d += 'M%s Q%s %s' % (pt(a), pt(b), pt(cc))
	return P(d, st=OUT, sw=12.5 * s) + P(d, st='#ff3a3a', sw=6.5 * s) + P(d, st='#ffb3a0', sw=1.8 * s, op=0.7)


def fx_gloom(d, hc, strong=True):
	"""shock: deep violet gloom pouring down over the upper face, with hard gloom streaks"""
	g = d.lin([(0, GLOOM, 0.9), (0.5, GLOOM, 0.62), (1, GLOOM, 0.0)], user=(0, 64, 0, 226))
	s = R(60, 40, 360, 190, fill=g, st=None)
	for x in (178, 196, 214, 232, 250, 268, 286, 304):
		ln = 58 if x in (196, 250, 286) else 38
		s += P('M%s L%s' % (pt((x, 84)), pt((x, 84 + ln))), st='#0c0420', sw=4, op=0.55)
	return G(s, clip=hc)


def fx_cold(d, hc):
	"""sad: cool blue shade washing over the whole face + faint gloom streaks"""
	g = d.lin([(0, SAD_BLUE, 0.36), (0.55, SAD_BLUE, 0.17), (1, SAD_BLUE, 0.07)], user=(0, 70, 0, 340))
	s = R(60, 40, 360, 320, fill=g, st=None)
	for x in (204, 222, 258, 276):
		s += P('M%s L%s' % (pt((x, 90)), pt((x, 90 + (34 if x in (222, 258) else 24)))), st='#1c2d6e', sw=3.5, op=0.45)
	return G(s, clip=hc)


def fx_eye_bags(c):
	"""sad: long hard shadows hanging under the eyes"""
	es = c.get('eye_scale', 1.0) * EYE_SCALE
	s = ''
	for side in (-1, 1):
		cx = 240 + side * EYE_DX
		y0 = EYE_Y + 16 * es
		bag = smooth([(cx - 24, y0), (cx, y0 + 12), (cx + 24, y0), (cx + 20, y0 + 16), (cx + side * 4, y0 + 34), (cx - 20, y0 + 16)])
		s += P(bag, fill='#1a1f5c', st=None, op=0.3)
		s += P('M%s Q%s %s' % (pt((cx - 18, y0 + 16)), pt((cx, y0 + 28)), pt((cx + 18, y0 + 16))), st='#1a1f5c', sw=3, op=0.45)
	return s


def fx_brow_shadow(d, c, hc):
	"""angry: deep shadow cast under the furrowed brows + a dark wash over the forehead"""
	es = c.get('eye_scale', 1.0) * EYE_SCALE
	base = EYE_Y - 24 * es - 16 + c.get('brow_dy', 0)
	g = d.lin([(0, '#2a0818', 0.5), (1, '#2a0818', 0.0)], user=(0, 64, 0, 190))
	s = R(60, 40, 360, 160, fill=g, st=None)
	o, m, i = BROWS['angry']
	for side in (-1, 1):
		cx = 240 + side * EYE_DX
		po, pm, pi = (cx + side * 24, base + o), (cx - side * 1, base + m), (cx - side * 26, base + i)
		sh = smooth([po, pm, pi, (pi[0] + side * 4, pi[1] + 26), (pm[0], pm[1] + 22), (po[0], po[1] + 16)])
		s += P(sh, fill='#2a0818', st=None, op=0.42)
	return G(s, clip=hc)


def fx_tears(c):
	s = ''
	es = c.get('eye_scale', 1.0) * EYE_SCALE
	for side in (-1, 1):
		cx = 240 + side * EYE_DX
		y0 = EYE_Y + 18 * es
		path = smooth([(cx - side * 14, y0 - 3), (cx + side * 10, y0 - 2), (cx + side * 15, y0 + 34), (cx + side * 12, y0 + 68),
			(cx + side * 2, y0 + 92), (cx - side * 8, y0 + 68), (cx - side * 5, y0 + 34)])
		s += P(path, fill='#b4e8ff', st='#1f5fae', sw=3.6, op=0.97)
		s += P(path, fill='#6cc4f5', st=None, op=0.4, extra=' transform="translate(%d 4)"' % (side * 4))
		s += P('M%s Q%s %s' % (pt((cx + side * 0, y0 + 8)), pt((cx + side * 6, y0 + 36)), pt((cx + side * 3, y0 + 64))), st=WHITE, sw=3.4, op=0.9)
		# droplets falling off the end of each stream
		s += P(drop(cx + side * 6, y0 + 112, 6.5), fill='#b4e8ff', st='#1f5fae', sw=3)
		s += C(cx + side * 14, y0 + 130, 3.6, fill='#b4e8ff', st='#1f5fae', sw=2.4)
	return s


def fx_shine(pos):
	"""happy: little aqua-white glints"""
	s = ''
	for (x, y, r) in pos:
		s += P(sparkle(x, y, r), fill=WHITE, st=None, op=0.95) + P(sparkle(x, y, r * 0.55), fill='#c9fff8', st=None)
	return s


def fx_shock_lines(x, y, side=-1):
	s = ''
	for k, a in enumerate((-60, -30, 0)):
		r = math.radians(a)
		dx, dy = math.cos(r) * side, math.sin(r)
		x0, y0 = x + dx * 6, y + dy * 6
		s += P('M%s L%s' % (pt((x0, y0)), pt((x0 + dx * 22, y0 + dy * 22))), st=OUT, sw=5)
	return s


def fx_sparkles(pos):
	s = ''
	for (x, y, r) in pos:
		s += P(sparkle(x, y, r), fill='#fff3a0', st=OUT, sw=2.5) + C(x, y, r * 0.18, fill=WHITE, st=None)
	return s


def fx_steam(x, y, s=1.0):
	"""little rising steam puffs (outlined circles merged into one soft cloud)"""
	pts = [(x, y, 7 * s), (x + 8 * s, y - 14 * s, 9 * s), (x + 2 * s, y - 30 * s, 11 * s), (x + 12 * s, y - 46 * s, 7 * s)]
	out = ''.join(C(px, py, r, fill='#f6f7fa', st='#9aa3ad', sw=3) for (px, py, r) in pts)
	out += ''.join(C(px, py, r - 2, fill='#f6f7fa', st=None) for (px, py, r) in pts)
	return G(out, op=0.95)


# ---------------------------------------------------------------------------- paws


def paw(x, y, fur, ang=0.0, w=26, h=22, glove=None):
	"""small front paw (or glove) - draw AFTER the held item so it wraps around it"""
	col = glove or fur
	p = smooth([(x - w, y - 4), (x - w * 0.6, y - h), (x + w * 0.3, y - h * 1.05), (x + w, y - h * 0.4), (x + w * 0.95, y + h * 0.5),
		(x + w * 0.2, y + h), (x - w * 0.7, y + h * 0.8)])
	s = P(p, fill=col, st=OUT, sw=5)
	for k in (-0.35, 0.1, 0.55):
		s += P('M%s Q%s %s' % (pt((x + w * k, y - h * 0.95)), pt((x + w * k + 3, y - h * 0.4)), pt((x + w * k, y - h * 0.05))), st=OUT, sw=3.2)
	if glove:
		s += P('M%s Q%s %s' % (pt((x - w * 0.6, y + h * 0.95)), pt((x, y + h * 1.25)), pt((x + w * 0.7, y + h * 0.9))), st=OUT, sw=4)
	return G(s, tf=rot(ang, x, y)) if ang else s


# ============================================================================ compositor


def n3(v):
	return ('%.3f' % v).rstrip('0').rstrip('.')


def body_outline(c):
	bw = c.get('bw', 1.0)
	half = [(240, 292), (304, 298), (360, 318), (402, 356), (422, 416), (432, 500), (436, 640), (240, 640)]
	return smooth(sym([(240 + (x - 240) * bw, y) for x, y in half]))


def draw_body(d, c, e):
	bw = c.get('bw', 1.0)
	X = lambda x: 240 + (x - 240) * bw
	bp = body_outline(c)
	bc = d.clip(bp)
	s = P(bp, fill=c['fur'], st=None)
	inner = ''
	if 'outfit' in c:
		o = c['outfit'](d, c, e)
		if abs(bw - 1.0) > 0.001:
			o = G(o, tf='translate(240 0) scale(%s 1) translate(-240 0)' % n3(bw))
		inner += o
	# hard two-tone cel shadow down the shadow side + the head's cast shadow on the chest
	sh = smooth([(X(334), 322), (X(398), 356), (X(420), 420), (X(432), 500), (X(440), 640), (X(380), 640),
		(X(374), 520), (X(362), 432), (X(340), 376), (X(300), 340)])
	inner += P(sh, fill=NIGHT_SH, st=None, op=0.26)
	inner += E(240, 338, 128 * c.get('hs', 1.0), 33, fill=NIGHT_SH, st=None, op=0.3)
	if e == 'sad':
		inner += P(bp, fill=SAD_BLUE, st=None, op=0.16)
	if c.get('arms', True):
		for side in (-1, 1):
			inner += P('M%s C%s %s %s' % (pt((X(240 - side * 140), 402)), pt((X(240 - side * 130), 452)),
				pt((X(240 - side * 124), 520)), pt((X(240 - side * 122), 640))), st=OUT, sw=4.5, op=0.9)
	# pool-light rim along the shadow-side shoulder
	peak = 0.95 if e == 'angry' else 0.7
	inner += P(bp, st=rim_grad(d, e, (X(290), 300), (X(420), 400), peak, 0.3), sw=22 if e == 'angry' else 17)
	s += G(inner, clip=bc)
	s += P(bp, st=OUT, sw=SIL)
	return s


def head_transform(c, e):
	tilt, bob = POSE[e]
	tilt += c.get('tilt', 0.0)
	bob += c.get('hy', 0.0)
	hs = c.get('hs', 1.0)
	tf = 'translate(0 %s) rotate(%s 240 340)' % (n(bob), n(tilt))
	if abs(hs - 1.0) > 0.001:
		tf += ' translate(240 340) scale(%s) translate(-240 -340)' % n3(hs)
	return tf


def capybara(cid, c, e):
	d = Doc()
	c = dict(c)
	c['_id'] = cid
	c['_irisgrad'] = d.lin([(0, c.get('iris2', darker(c['iris'], 0.65))), (0.5, c['iris']), (1, lighter(c['iris'], 0.4))])
	out = ''
	if 'behind' in c:
		out += c['behind'](d, c, e)       # behind everything (not moving with the head)
	out += draw_body(d, c, e)
	if 'neck' in c:
		out += c['neck'](d, c, e)
	head = ''
	if 'back' in c:
		head += c['back'](d, c, e)
	head += draw_ears(d, c, e)
	hb, hp, hc = draw_head_base(d, c, e)
	head += hb
	head += draw_muzzle(d, c, hc, e)
	head += draw_head_rim(d, c, e, hp, hc)
	if 'fur_face' in c:
		head += c['fur_face'](d, c, e)  # smudges / freckles on the fur (under the features)
	head += draw_blush(c, e)
	head += draw_whiskers(c)
	head += draw_nose(d, c)
	head += draw_mouth(d, c, e)
	# expression lighting goes over the fur but under the eyes, so the eyes stay readable
	if e == 'shock':
		head += fx_gloom(d, hc, True)
	elif e == 'sad':
		head += fx_cold(d, hc) + fx_eye_bags(c)
	elif e == 'angry':
		head += fx_brow_shadow(d, c, hc)
	head += draw_eyes(d, c, e)
	head += draw_brows(c, e)
	if 'face' in c:
		head += c['face'](d, c, e)
	if 'outline' in c:
		head += c['outline'](d, c, e, hp)
	else:
		head += P(hp, st=OUT, sw=SIL)
	if e == 'sad':
		head += fx_tears(c)
	if 'hat' in c:
		head += c['hat'](d, c, e)
	# expression overlays
	if e == 'shock':
		sx, sy = c.get('fx_sweat', (366, 150))
		head += fx_sweat_big(sx, sy)
		lx, ly = c.get('fx_lines', (110, 116))
		head += fx_shock_lines(lx, ly, -1)
	elif e == 'angry':
		ax, ay = c.get('fx_anger', (352, 146))
		head += fx_anger(ax, ay, 1.3)
	elif e == 'happy':
		sp = c.get('fx_sparkle', [(98, 140, 15), (386, 176, 12), (106, 196, 8)])
		head += fx_sparkles(sp)
		head += fx_shine([(sp[0][0] + 22, sp[0][1] - 26, 7), (sp[1][0] - 14, sp[1][1] + 26, 6)])
	out += G(head, tf=head_transform(c, e))
	if 'front' in c:
		out += c['front'](d, c, e)
	return d.render(G(out, tf='translate(0 %s)' % n(SHIFT)))


# ============================================================================ outfit helpers


def fold(d_, col=OUT, sw=3.5, op=0.35):
	return P(d_, st=col, sw=sw, op=op)


def button(x, y, r=6, col='#f2c14e'):
	return C(x, y, r, fill=col, st=OUT, sw=2.5) + C(x - r * 0.3, y - r * 0.3, r * 0.3, fill=WHITE, st=None, op=0.6)


def stroke2(d_, col, w, ow=None):
	"""outlined stroke (dark border + coloured core)"""
	return P(d_, st=OUT, sw=ow or (w + 4)) + P(d_, st=col, sw=w)


def stripes_h(y0, y1, step, h, col, x0=-40, x1=520):
	s = ''
	y = y0
	while y < y1:
		s += R(x0, y, x1 - x0, h, fill=col, st=None)
		y += step
	return s


def pixel_letters(word, x, y, sc, col, sw=2.0):
	"""tiny stroke font for labels painted on props (drawn as paths, not text)"""
	G_ = {
		'P': 'M0,6 L0,0 L3,0 Q4,0 4,1.5 Q4,3 3,3 L0,3',
		'R': 'M0,6 L0,0 L3,0 Q4,0 4,1.5 Q4,3 3,3 L0,3 M2,3 L4,6',
		'E': 'M4,0 L0,0 L0,6 L4,6 M0,3 L3,3',
		'S': 'M4,0.6 Q3.6,0 2,0 Q0,0 0,1.5 Q0,3 2,3 Q4,3 4,4.5 Q4,6 2,6 Q0.4,6 0,5.4',
	}
	s = ''
	for i, ch in enumerate(word):
		g = G_[ch]
		tf = 'translate(%s %s) scale(%s)' % (n(x + i * 5.6 * sc), n(y), n3(sc))
		s += '<path d="%s" fill="none" stroke="%s" stroke-width="%s" stroke-linecap="round" stroke-linejoin="round" transform="%s"/>' % (
			g, col, n3(sw / sc), tf)
	return s


def hat_pose(e, base_rot, cx=240, cy=100, jump=10):
	"""small hat reactions: hop on shock, sag on sad"""
	tf = rot(base_rot, cx, cy)
	if e == 'shock':
		tf = 'translate(0 %s) ' % n(-min(jump, 10)) + rot(base_rot - 4, cx, cy)
	elif e == 'sad':
		tf = 'translate(0 4) ' + rot(base_rot + 4, cx, cy)
	elif e == 'happy':
		tf = 'translate(0 -3) ' + rot(base_rot - 2, cx, cy)
	return tf


def hop_lines(x, y, w=40):
	s = ''
	for dx in (-w * 0.5, 0, w * 0.5):
		s += P('M%s L%s' % (pt((x + dx, y)), pt((x + dx * 1.15, y - 14))), st=OUT, sw=4)
	return s


# ============================================================================ characters
# ---------------------------------------------------------------------------- MOCHI (player)

HOODIE = '#f28a2e'


def mochi_outfit(d, c, e):
	s = R(-40, 280, 560, 380, fill=HOODIE, st=None)
	s += P('M240,372 L240,640', st=darker(HOODIE, 0.4), sw=3.5, op=0.6)
	s += P('M156,530 Q240,512 324,530', st=darker(HOODIE, 0.4), sw=4, op=0.55)
	# little yuzu patch sewn on the hoodie
	s += C(282, 412, 15, fill='#ffd23c', st=OUT, sw=3.5) + E(277, 407, 4, 3, fill=WHITE, st=None, op=0.7)
	s += P('M284,397 Q292,388 302,392 Q294,402 284,397 Z', fill='#5dbb4c', st=OUT, sw=2.5)
	s += C(282, 412, 19, st='#fff3d6', sw=2, op=0.8, extra=' stroke-dasharray="3 3"')
	return s


def towel_strip(d, pts, stripe_y, side):
	tp = smooth(pts)
	k = d.clip(tp)
	s = P(tp, fill='#fdfcf6', st=None)
	inner = stripes_h(stripe_y, stripe_y + 1, 99, 11, '#79c3ea') + stripes_h(stripe_y + 18, stripe_y + 19, 99, 6, '#79c3ea')
	# terry-cloth texture + fold shade on the inner edge
	inner += P(smooth([(pts[0][0], pts[0][1]), (pts[-1][0], pts[-1][1] - 40), (pts[-1][0] + side * 16, 520), (pts[-1][0] + side * 30, 300)]),
		fill='#d7dde5', st=None, op=0.8)
	s += G(inner, clip=k)
	s += P(tp, st=OUT, sw=5)
	return s


def mochi_neck(d, c, e):
	s = ''
	# ribbed hoodie neckline
	s += P('M176,330 Q240,392 304,330', st=OUT, sw=17) + P('M176,330 Q240,392 304,330', st=darker(HOODIE, 0.18), sw=10)
	# drawstrings
	for (x0, x1, y1) in ((222, 214, 448), (258, 266, 442)):
		s += stroke2('M%s Q%s %s' % (pt((x0, 362)), pt((x0 - 2, 404)), pt((x1, y1))), '#ffffff', 4.5)
		s += R(x1 - 4, y1 - 2, 8, 14, rx=2, fill='#5a4a40', st=OUT, sw=2.5)
	# towel draped around the neck, both ends hanging down the chest
	left = [(186, 306), (150, 310), (122, 334), (114, 392), (116, 470), (124, 508), (176, 512), (178, 440), (180, 378), (196, 336)]
	right = [(294, 306), (334, 312), (358, 336), (366, 386), (362, 440), (356, 466), (310, 470), (304, 420), (300, 372), (286, 334)]
	s += towel_strip(d, right, 430, 1)
	s += towel_strip(d, left, 470, -1)
	# little fringe at the long end
	for x in (130, 140, 150, 160, 170):
		s += P('M%s L%s' % (pt((x, 512)), pt((x - 1, 524))), st=OUT, sw=3)
	return s


def mochi_hat(d, c, e):
	# the little yuzu balanced on Mochi's head
	cx, cy, r = 254, 54, 32
	g = d.rad([(0, '#fff6a0'), (0.45, '#ffd23c'), (1, '#f2961a')], cx=0.36, cy=0.32, r=0.72)
	s = C(cx, cy, r, fill=g, st=OUT, sw=5.5)
	for (dx, dy) in ((-14, 4), (-4, 14), (10, 8), (16, -6), (2, -2), (-10, -10), (6, 20), (-18, 14), (18, 16)):
		s += C(cx + dx, cy + dy, 1.8, fill='#d98114', st=None, op=0.55)
	s += E(cx - 10, cy - 12, 9, 6, fill=WHITE, st=None, op=0.75, extra=' transform="%s"' % rot(-30, cx - 10, cy - 12))
	s += P('M%s Q%s %s' % (pt((cx + 1, cy - r + 2)), pt((cx + 2, cy - r - 8)), pt((cx + 6, cy - r - 12))), st='#6b4a2a', sw=4.5)
	leaf = 'M%s Q%s %s Q%s %s Z' % (pt((cx + 4, cy - r - 6)), pt((cx + 18, cy - r - 24)), pt((cx + 44, cy - r - 12)),
		pt((cx + 28, cy - r + 2)), pt((cx + 4, cy - r - 6)))
	s += P(leaf, fill='#5dbb4c', st=OUT, sw=3.5)
	s += P('M%s Q%s %s' % (pt((cx + 8, cy - r - 7)), pt((cx + 24, cy - r - 14)), pt((cx + 38, cy - r - 11))), st='#3c8a30', sw=2.5)
	if e == 'shock':
		return G(s, tf='translate(10 2) ' + rot(-24, cx, cy)) + hop_lines(cx - 50, 60, 16) + hop_lines(cx + 54, 58, 16)
	if e == 'sad':
		return G(s, tf='translate(26 12) ' + rot(28, cx, cy))
	if e == 'happy':
		return G(s, tf='translate(-2 -3) ' + rot(-8, cx, cy))
	if e == 'angry':
		return G(s, tf=rot(14, cx, cy))
	return G(s, tf=rot(8, cx, cy))


MOCHI = dict(fur='#d0965a', shade='#ae733f', muzzle='#ebc08c', inner='#a8653c', iris='#9a6230', iris2='#3a210f',
	outfit=mochi_outfit, neck=mochi_neck, hat=mochi_hat, mouth='w',
	fx_sparkle=[(96, 140, 15), (388, 120, 12), (106, 200, 8)])


# ---------------------------------------------------------------------------- CAPTAIN COCO

NAVY = '#203a6e'
GOLD = '#f2c14e'


def coco_outfit(d, c, e):
	shirt = 'M-40,330 L160,326 Q240,392 320,326 L520,330 L520,640 L-40,640 Z'
	k = d.clip(shirt)
	s = G(R(-40, 300, 560, 360, fill='#f7f5ef', st=None) + stripes_h(372, 640, 34, 16, NAVY), clip=k)
	s += P('M160,326 Q240,392 320,326', st=OUT, sw=13) + P('M160,326 Q240,392 320,326', st=NAVY, sw=7)
	# pocket watch on its gold chain
	chain = 'M196,384 Q242,428 298,402'
	s += P(chain, st=OUT, sw=6) + P(chain, st=GOLD, sw=3.2, extra=' stroke-dasharray="5 3"')
	s += C(196, 384, 5, fill=GOLD, st=OUT, sw=2.5)
	s += C(304, 412, 19, fill=GOLD, st=OUT, sw=4) + C(304, 412, 13, fill='#fffbea', st=OUT, sw=2)
	s += P('M304,412 L304,403 M304,412 L310,415', st=OUT, sw=2.2) + R(299, 388, 10, 7, rx=2, fill=GOLD, st=OUT, sw=2)
	return s


def coco_neck(d, c, e):
	# red sailor kerchief knot
	red = '#dd3b3b'
	s = P('M212,360 L196,412 L226,398 Z', fill=darker(red, 0.15), st=OUT, sw=4)
	s += P('M268,360 L284,412 L254,398 Z', fill=darker(red, 0.15), st=OUT, sw=4)
	s += P(smooth([(240, 344), (262, 350), (264, 370), (240, 378), (216, 370), (218, 350)]), fill=red, st=OUT, sw=4.5)
	s += E(234, 356, 7, 4, fill=WHITE, st=None, op=0.4)
	return s


def anchor(cx, cy, s=1.0, col=GOLD):
	d_ = ('M%s L%s M%s L%s M%s Q%s %s' % (pt((cx, cy - 13 * s)), pt((cx, cy + 15 * s)), pt((cx - 10 * s, cy - 5 * s)), pt((cx + 10 * s, cy - 5 * s)),
		pt((cx - 14 * s, cy + 5 * s)), pt((cx, cy + 22 * s)), pt((cx + 14 * s, cy + 5 * s))))
	return (P(d_, st=OUT, sw=8 * s) + C(cx, cy - 17 * s, 4.5 * s, st=OUT, sw=7 * s) + P(d_, st=col, sw=4 * s) + C(cx, cy - 17 * s, 4.5 * s, st=col, sw=3 * s))


def coco_hat(d, c, e):
	white = '#fbfaf5'
	crown = smooth(sym([(240, 22), (302, 25), (352, 40), (380, 62), (360, 84), (302, 94), (240, 97)]))
	k = d.clip(crown)
	s = P(crown, fill=white, st=None)
	s += G(E(250, 100, 150, 30, fill='#d5dbe4', st=None) + E(196, 40, 60, 12, fill=WHITE, st=None, op=0.9), clip=k)
	s += P(crown, st=OUT, sw=SW)
	s += P('M156,86 Q240,100 324,86 L326,110 Q240,124 154,110 Z', fill=NAVY, st=OUT, sw=5)
	s += P('M160,98 Q240,112 320,98', st=GOLD, sw=4)
	s += C(160, 98, 5, fill=GOLD, st=OUT, sw=2.5) + C(320, 98, 5, fill=GOLD, st=OUT, sw=2.5)
	visor = 'M154,108 Q240,124 326,108 Q338,124 306,136 Q240,148 174,136 Q142,124 154,108 Z'
	s += P(visor, fill='#16161f', st=OUT, sw=5)
	s += P('M176,124 Q240,134 300,124', st=WHITE, sw=3.5, op=0.35)
	s += anchor(240, 60, 1.0)
	return G(s, tf=hat_pose(e, -7, 240, 100))


COCO = dict(fur='#b8633a', shade='#924a27', muzzle='#d68c60', inner='#7a3b22', iris='#3f86e0', iris2='#14305e',
	lashes=2, brow_w=9.5, outfit=coco_outfit, neck=coco_neck, hat=coco_hat, mouth='smile', ears=(116, 104, 40),
	fx_sparkle=[(92, 160, 15), (392, 176, 12), (104, 212, 8)], fx_anger=(356, 156))


# ---------------------------------------------------------------------------- WISP VANDERLOO (magician)

VIOLET = '#7a48c8'
VIOLET_D = '#55309a'
SILVER = '#e4e9f2'


def silver_star(x, y, r, a=-90):
	return P(star(x, y, r, 0.46, 5, a), fill=SILVER, st=OUT, sw=2.5)


def wisp_outfit(d, c, e):
	s = R(-40, 280, 560, 380, fill=VIOLET, st=None)
	s += fold('M150,380 Q170,500 160,640', OUT, 4, 0.3) + fold('M330,380 Q312,500 322,640', OUT, 4, 0.3)
	s += fold('M96,430 Q110,540 104,640', OUT, 3.5, 0.25) + fold('M384,430 Q372,540 378,640', OUT, 3.5, 0.25)
	for (x, y, r, a) in ((112, 428, 12, -80), (372, 446, 11, -100), (150, 540, 10, -90), (336, 552, 13, -70), (88, 560, 9, -95),
		(398, 590, 9, -90), (128, 362, 7, -90), (356, 372, 8, -85)):
		s += silver_star(x, y, r, a)
	return s


def wisp_neck(d, c, e):
	s = ''
	# high standing cape collar (behind the head)
	for side in (-1, 1):
		pts = [(240 + side * 58, 336), (240 + side * 112, 324), (240 + side * 152, 292), (240 + side * 178, 214),
			(240 + side * 140, 236), (240 + side * 104, 262), (240 + side * 70, 300)]
		fl = smooth(pts)
		s += P(fl, fill=VIOLET, st=OUT, sw=5)
		inner = smooth([(240 + side * 72, 322), (240 + side * 112, 312), (240 + side * 144, 284), (240 + side * 162, 238),
			(240 + side * 134, 252), (240 + side * 102, 276), (240 + side * 76, 306)])
		s += P(inner, fill='#2b1856', st=None)
		s += silver_star(240 + side * 136, 280, 6)
	# shirt front + dark vest
	s += P('M194,326 L240,446 L286,326 Z', fill='#f6f3fb', st=OUT, sw=4.5)
	s += P('M194,326 L222,400 L208,404 L180,332 Z', fill='#231a33', st=OUT, sw=3.5)
	s += P('M286,326 L258,400 L272,404 L300,332 Z', fill='#231a33', st=OUT, sw=3.5)
	s += button(240, 392, 4, SILVER) + button(240, 416, 4, SILVER)
	# violet bow tie with a silver star
	s += P('M240,352 L212,338 L210,368 Z', fill=VIOLET, st=OUT, sw=4) + P('M240,352 L268,338 L270,368 Z', fill=VIOLET, st=OUT, sw=4)
	s += C(240, 352, 8, fill=VIOLET_D, st=OUT, sw=3.5) + P(star(240, 352, 5, 0.45), fill=SILVER, st=None)
	# cape clasp chain
	s += P('M176,356 Q240,384 304,356', st=OUT, sw=6) + P('M176,356 Q240,384 304,356', st=GOLD, sw=3, extra=' stroke-dasharray="5 3"')
	s += P(star(176, 354, 10, 0.5), fill=GOLD, st=OUT, sw=3) + P(star(304, 354, 10, 0.5), fill=GOLD, st=OUT, sw=3)
	return s


def wisp_hat(d, c, e):
	black = '#1f1a28'
	s = ''
	s += P('M176,100 L166,8 Q240,-4 314,8 L304,100 Z', fill=black, st=OUT, sw=SW)
	s += P('M186,96 L178,16 Q190,12 200,11 L206,96 Z', fill=WHITE, st=None, op=0.12)
	s += E(240, 8, 74, 12, fill='#2e2838', st=OUT, sw=5)
	s += P('M172,70 L308,70 L305,98 L175,98 Z', fill=VIOLET, st=OUT, sw=4.5)
	s += P(star(284, 84, 9, 0.46), fill=SILVER, st=OUT, sw=2.5)
	s += P('M128,100 Q240,80 352,100 Q364,112 342,118 Q240,102 138,118 Q116,112 128,100 Z', fill=black, st=OUT, sw=5)
	# aqua rim on the shadow side of the black hat (separates it from the night background)
	s += P('M306,16 L298,66', st=rim_col(e), sw=3.2, op=0.75) + P('M318,106 Q340,108 350,104', st=rim_col(e), sw=3, op=0.7)
	if e == 'happy':
		s += P(sparkle(330, 22, 12), fill='#fff3a0', st=OUT, sw=2.5)
	return G(s, tf=hat_pose(e, 8, 240, 100, 3))


def wisp_face(d, c, e):
	# monocle on the right eye + chain
	x, y = 240 + EYE_DX, EYE_Y
	s = C(x, y, 31, fill='#dff2ff', st=None, op=0.18)
	s += C(x, y, 31, st=OUT, sw=10) + C(x, y, 31, st='#f0c75a', sw=4.5)
	s += P('M%s Q%s %s' % (pt((x - 18, y - 16)), pt((x - 4, y - 28)), pt((x + 14, y - 24))), st=WHITE, sw=3, op=0.8)
	ch = 'M%s Q%s %s' % (pt((x + 24, y + 20)), pt((x + 50, y + 70)), pt((x + 40, y + 150)))
	s += P(ch, st=OUT, sw=5.5) + P(ch, st='#f0c75a', sw=2.6, extra=' stroke-dasharray="4 3"')
	return s


def wisp_front(d, c, e):
	# white-gloved paw with a magic wand
	ang = {'normal': 0, 'happy': -14, 'shock': 18, 'angry': -6, 'sad': 22}[e]
	s = ''
	wand = 'M352,408 L414,296'
	s += P(wand, st=OUT, sw=14) + P(wand, st='#15121c', sw=8)
	s += P('M405,312 L414,296', st=OUT, sw=14) + P('M405,312 L414,296', st=WHITE, sw=8)
	if e == 'happy':
		s += fx_sparkles([(424, 280, 12), (398, 270, 7)])
	s += paw(356, 410, c['fur'], -20, 28, 24, glove='#ffffff')
	return G(s, tf=rot(ang, 356, 430))


WISP = dict(fur='#6b4430', shade='#4e2f1f', muzzle='#8e6046', inner='#3e2418', iris='#b07cff', iris2='#2d1460',
	lid=0.32, mouth='smirk', hy=12, ears=(110, 100, 34), arms=False, tilt=1.5, brow='#2a1a10',
	outfit=wisp_outfit, neck=wisp_neck, hat=wisp_hat, face=wisp_face, front=wisp_front,
	fx_sparkle=[(96, 150, 15), (396, 210, 11), (104, 206, 8)], fx_anger=(118, 150), fx_sweat=(118, 150), fx_lines=(380, 150))


# ---------------------------------------------------------------------------- BRUNO BRAWNSWORTH (wrestler)

BRUNO_RED = '#d8343a'


def bruno_outfit(d, c, e):
	s = ''
	# chest fur patch + muscles (visible between the singlet straps)
	s += E(240, 420, 70, 60, fill=lighter(c['fur'], 0.12), st=None, op=0.6)
	s += P('M186,386 Q210,410 238,398', st=OUT, sw=4, op=0.55) + P('M242,398 Q270,410 294,386', st=OUT, sw=4, op=0.55)
	s += P('M108,404 Q124,370 160,360', st=OUT, sw=4, op=0.45) + P('M372,404 Q356,370 320,360', st=OUT, sw=4, op=0.45)
	sing = ('M148,312 L188,312 C192,370 206,422 222,452 Q240,462 258,452 C274,422 288,370 292,312 L332,312 '
		'C338,380 362,430 424,468 L444,640 L36,640 L56,468 C118,430 142,380 148,312 Z')
	k = d.clip(sing)
	s += P(sing, fill='#cf3434', st=None)
	s += G(P(sing, fill='#a82424', st=None, extra=' transform="translate(16 10)"') + P(sing, fill='#cf3434', st=None, extra=' transform="translate(-6 -2)"'), clip=k)
	neck = 'M188,312 C192,370 206,422 222,452 Q240,462 258,452 C274,422 288,370 292,312'
	s += P(neck, st=OUT, sw=11) + P(neck, st=GOLD, sw=4.5)
	s += P('M148,312 C142,380 118,430 56,468', st=OUT, sw=10) + P('M148,312 C142,380 118,430 56,468', st=GOLD, sw=4)
	s += P('M332,312 C338,380 362,430 424,468', st=OUT, sw=10) + P('M332,312 C338,380 362,430 424,468', st=GOLD, sw=4)
	s += P(star(240, 520, 22, 0.45), fill=GOLD, st=OUT, sw=4)
	return s


def bruno_hat(d, c, e):
	s = ''
	flap = {'normal': 0, 'happy': -6, 'shock': -16, 'angry': 10, 'sad': 22}[e]
	tails = ''
	for (a, b, tip) in (((372, 120), (384, 136), (424, 96 + flap)), ((376, 136), (378, 150), (428, 156 + flap * 0.5))):
		mid = ((a[0] + tip[0]) / 2.0, (a[1] + tip[1]) / 2.0 - 8)
		tp = smooth([a, (mid[0], mid[1] - 6), tip, (mid[0] + 4, mid[1] + 12), b])
		tails += P(tp, fill=BRUNO_RED, st=OUT, sw=5)
		tails += P('M%s Q%s %s' % (pt(a), pt(mid), pt(tip)), st='#a82424', sw=3, op=0.6)
	s += tails
	band = 'M106,112 Q240,86 374,112 L376,142 Q240,116 104,142 Z'
	k = d.clip(band)
	s += P(band, fill=BRUNO_RED, st=None)
	s += G(R(80, 128, 320, 30, fill='#a82424', st=None, op=0.8, extra=' transform="%s"' % rot(0, 240, 130))
		+ P('M106,118 Q240,94 374,118', st=WHITE, sw=4, op=0.45), clip=k)
	s += P(band, st=OUT, sw=5.5)
	s += P(smooth([(364, 112), (384, 116), (390, 132), (380, 148), (362, 146), (358, 128)]), fill=BRUNO_RED, st=OUT, sw=5)
	return s


def bruno_face(d, c, e):
	# old scar through the left eyebrow
	sc = '#f0c4a8'
	s = P('M162,118 L188,158', st=OUT, sw=8, op=0.25) + P('M162,118 L188,158', st=sc, sw=4.5)
	s += P('M168,134 L178,128 M174,144 L184,138', st=sc, sw=3)
	return s


BRUNO = dict(fur='#7a4f33', shade='#5b3822', muzzle='#a0714f', inner='#48291a', iris='#8a5328', iris2='#2a1608',
	eye_scale=0.84, brow_w=11, hs=1.16, bw=1.1, arms=False, ears=(100, 80, 14), brow='#2a1a10',
	outfit=bruno_outfit, hat=bruno_hat, face=bruno_face, mouth='smile',
	fx_sweat=(112, 150), fx_lines=(100, 104), fx_anger=(124, 150),
	fx_sparkle=[(84, 150, 15), (410, 210, 12), (96, 206, 8)])


# ---------------------------------------------------------------------------- LULU STARLING (pop idol)

PINK = '#ff6fae'
PINK_D = '#e04d92'


def scallop(pts, amp, side=1):
	"""bumpy frill: quadratic bumps between consecutive points (bulging to the left of travel*side)"""
	d_ = 'M' + pt(pts[0])
	for i in range(1, len(pts)):
		a, b = pts[i - 1], pts[i]
		mx, my = (a[0] + b[0]) / 2.0, (a[1] + b[1]) / 2.0
		dx, dy = b[0] - a[0], b[1] - a[1]
		ln = math.hypot(dx, dy) or 1
		nx, ny = -dy / ln * side, dx / ln * side
		d_ += ' Q%s %s' % (pt((mx + nx * amp * 2, my + ny * amp * 2)), pt(b))
	return d_


def lulu_back(d, c, e):
	# the two big bow loops spread behind the ears
	s = ''
	wig = {'happy': -4, 'shock': -6, 'sad': 8}.get(e, 0)
	for side in (-1, 1):
		loop = smooth([(240 + side * 8, 66), (240 + side * 30, 30 + wig), (240 + side * 76, 12 + wig), (240 + side * 112, 32 + wig),
			(240 + side * 110, 74 + wig * 0.5), (240 + side * 72, 92), (240 + side * 18, 80)])
		k = d.clip(loop)
		inner = P(smooth([(240 + side * 14, 70), (240 + side * 44, 46 + wig), (240 + side * 80, 40 + wig), (240 + side * 66, 70),
			(240 + side * 22, 78)]), fill=PINK_D, st=None, op=0.85)
		for (dx, dy) in ((50, 30), (88, 34), (96, 62), (62, 66), (30, 52)):
			inner += C(240 + side * dx, dy + wig * 0.6, 5.5, fill=WHITE, st=None, op=0.9)
		s += P(loop, fill=PINK, st=None) + G(inner, clip=k) + P(loop, st=OUT, sw=5.5)
	return s


def lulu_hat(d, c, e):
	s = P(smooth([(240, 52), (258, 54), (264, 72), (256, 90), (240, 92), (224, 90), (216, 72), (222, 54)]), fill='#ff8cc4', st=OUT, sw=5)
	s += P('M232,62 Q240,58 248,62', st=WHITE, sw=3, op=0.7)
	s += P(heart(240, 74, 7), fill='#ff3d7f', st=OUT, sw=2.5)
	return s


def lulu_outfit(d, c, e):
	s = R(-40, 280, 560, 380, fill='#ff86c2', st=None)
	s += P('M120,460 Q240,500 360,460', st='#e8609f', sw=5, op=0.8)
	for (x, y, r) in ((150, 420, 9), (318, 448, 11), (204, 492, 7), (360, 520, 8), (110, 540, 10), (276, 560, 8), (180, 590, 9)):
		s += P(sparkle(x, y, r), fill='#fff6fb', st=None)
	return s


def lulu_neck(d, c, e):
	s = ''
	# puffy sleeves
	for side in (-1, 1):
		x = 240 + side * 142
		pp = smooth([(x - side * 40, 340), (x + side * 10, 330), (x + side * 46, 360), (x + side * 52, 410), (x + side * 30, 446),
			(x - side * 20, 446), (x - side * 46, 410)])
		s += P(pp, fill='#ff9fd0', st=OUT, sw=5)
		for k in (-20, 0, 20):
			s += P('M%s Q%s %s' % (pt((x + side * k * 0.6, 346)), pt((x + side * (k + 8), 392)), pt((x + side * k * 0.8, 440))), st='#e8609f', sw=3, op=0.7)
		s += P('M%s Q%s %s' % (pt((x - side * 40, 438)), pt((x, 456)), pt((x + side * 34, 440))), st=WHITE, sw=6)
	# white scalloped collar
	for side in (-1, 1):
		top = [(240, 346), (240 + side * 30, 334), (240 + side * 70, 326)]
		edge = [(240 + side * 70, 326), (240 + side * 84, 346), (240 + side * 76, 368), (240 + side * 52, 380), (240 + side * 24, 378), (240, 364)]
		ed = resample(sample_smooth(edge, 6), 7)
		d_ = scallop(ed, 4, -side) + ' L%s Q%s %s Z' % (pt((240, 346)), pt((240 + side * 40, 322)), pt((240 + side * 70, 326)))
		s += P(d_, fill='#fffaf4', st=OUT, sw=4.5)
	s += P(heart(240, 362, 11), fill='#ff3d7f', st=OUT, sw=3.5) + E(235, 356, 3.5, 2.5, fill=WHITE, st=None, op=0.8)
	return s


def lulu_face(d, c, e):
	s = ''
	for side in (-1, 1):
		for (dx, dy, r) in ((-12, -6, 6), (6, 4, 4.5), (14, -10, 3.5)):
			s += P(sparkle(240 + side * 100 + dx, 226 + dy, r), fill='#ff4fa0' if r > 5 else WHITE, st=None, op=0.95)
	return s


def lulu_front(d, c, e):
	tilt = {'normal': 0, 'happy': -10, 'shock': 14, 'angry': -4, 'sad': 18}[e]
	s = ''
	s += P('M352,360 L370,430', st=OUT, sw=22) + P('M352,360 L370,430', st=PINK, sw=15)
	s += P('M350,350 L356,372', st=OUT, sw=24) + P('M350,350 L356,372', st='#ffd6ea', sw=17)
	g = d.rad([(0, WHITE), (0.5, '#c9d0d8'), (1, '#7d8794')], cx=0.35, cy=0.3, r=0.75)
	s += C(346, 330, 23, fill=g, st=OUT, sw=5)
	k = d.clip('M323,330 A23,23 0 1 0 369,330 A23,23 0 1 0 323,330 Z')
	grid = ''
	for i in range(-3, 4):
		grid += P('M%s L%s' % (pt((330 + i * 8, 300)), pt((360 + i * 8, 360))), st='#6b7480', sw=1.6, op=0.6)
		grid += P('M%s L%s' % (pt((362 + i * 8, 300)), pt((332 + i * 8, 360))), st='#6b7480', sw=1.6, op=0.6)
	s += G(grid, clip=k)
	s += paw(368, 414, c['fur'], -12, 26, 22)
	if e == 'happy':
		s += fx_sparkles([(392, 300, 11), (318, 296, 7)])
	return G(s, tf=rot(tilt, 368, 430))


LULU = dict(fur='#eac272', shade='#c99c4c', muzzle='#f7dc9e', inner='#c98a6a', iris='#ff4fa6', iris2='#6e0f46',
	lashes=3, star_eyes=True, blush_op=0.42, blush='#ff5e9e', mouth='smile', ears=(100, 80, 16),
	back=lulu_back, hat=lulu_hat, outfit=lulu_outfit, neck=lulu_neck, face=lulu_face, front=lulu_front,
	fx_sparkle=[(84, 150, 15), (100, 214, 9), (396, 120, 13)], fx_sweat=(370, 150))


# ---------------------------------------------------------------------------- PEPPER QUILL (journalist)

TEAL = '#3e7f88'


def pepper_outfit(d, c, e):
	s = R(-40, 280, 560, 380, fill=TEAL, st=None)
	s += P('M196,326 L240,440 L284,326 Z', fill='#fbfaf6', st=None)
	for side in (-1, 1):
		lap = [(240 + side * 44, 324), (240 + side * 92, 336), (240 + side * 70, 380), (240 + side * 86, 398), (240 + side * 14, 470), (240 + side * 4, 444)]
		s += P(poly(lap), fill=darker(TEAL, 0.2), st=OUT, sw=4.5)
	s += button(232, 500, 6, '#2b4e54') + button(232, 556, 6, '#2b4e54')
	return s


def pepper_neck(d, c, e):
	s = ''
	for side in (-1, 1):
		s += P(poly([(240 + side * 4, 340), (240 + side * 40, 326), (240 + side * 30, 362)]), fill='#fbfaf6', st=OUT, sw=4)
	s += P('M240,348 L230,362 L236,430 L240,438 L246,430 L250,362 Z', fill='#c8423b', st=OUT, sw=4)
	s += P(poly([(230, 342), (250, 342), (246, 360), (234, 360)]), fill='#e0574f', st=OUT, sw=4)
	# camera on its strap
	strap = 'M178,322 C186,352 218,378 262,388'
	s += P(strap, st=OUT, sw=11) + P(strap, st='#2a2a30', sw=6)
	strap2 = 'M304,322 C312,346 322,368 332,386'
	s += P(strap2, st=OUT, sw=11) + P(strap2, st='#2a2a30', sw=6)
	s += R(252, 380, 90, 56, rx=10, fill='#2a2a32', st=OUT, sw=5)
	s += R(256, 382, 82, 12, rx=5, fill='#b9c2cc', st=None)
	s += R(262, 366, 22, 16, rx=3, fill='#d9dee5', st=OUT, sw=3.5)
	s += C(298, 412, 21, fill='#15151a', st=OUT, sw=4) + C(298, 412, 13, fill='#3a6fa8', st=OUT, sw=2.5)
	s += C(293, 407, 4.5, fill=WHITE, st=None, op=0.85)
	s += C(328, 392, 4, fill='#ff4444', st=None)
	return s


def pepper_hat(d, c, e):
	tweed = '#8b6a48'
	top = smooth(sym([(240, 30), (300, 32), (352, 46), (382, 72), (366, 98), (302, 106), (240, 108)]))
	k = d.clip(top)
	s = P(top, fill=tweed, st=None)
	inner = P(top, fill='#6c4f33', st=None, extra=' transform="translate(14 12)"') + P(top, fill=tweed, st=None, extra=' transform="translate(-4 -4)"')
	for x in range(100, 400, 22):
		inner += P('M%s L%s' % (pt((x, 20)), pt((x - 30, 120))), st='#a98760', sw=2, op=0.55)
	for y in range(36, 120, 18):
		inner += P('M%s L%s' % (pt((90, y)), pt((400, y + 4))), st='#5e4330', sw=1.6, op=0.4)
	inner += P('M240,32 Q196,56 140,96 M240,32 Q284,56 342,96 M240,32 L240,106', st=OUT, sw=2.5, op=0.6)
	s += G(inner, clip=k) + P(top, st=OUT, sw=SW)
	s += C(240, 32, 7, fill='#6c4f33', st=OUT, sw=3.5)
	s += P('M170,98 Q240,114 310,98 Q310,128 240,136 Q170,128 170,98 Z', fill='#5a3f28', st=OUT, sw=5)
	s += P('M186,116 Q240,126 294,116', st=WHITE, sw=3, op=0.25)
	# PRESS card tucked into the band
	card = R(118, 64, 56, 34, rx=3, fill='#fdfcf5', st=OUT, sw=3.5) + R(120, 66, 52, 8, fill='#d83b3b', st=None)
	card += pixel_letters('PRESS', 125, 79, 1.55, OUT, 2.2)
	s += G(card, tf=rot(-18, 146, 82))
	# pencil on the other side
	pen = R(322, 50, 12, 62, rx=2, fill='#ffd23c', st=OUT, sw=3.5) + R(322, 44, 12, 10, rx=3, fill='#ff8fa3', st=OUT, sw=3)
	pen += P('M322,112 L328,126 L334,112 Z', fill='#f3d4a6', st=OUT, sw=3)
	s += G(pen, tf=rot(28, 328, 86))
	return G(s, tf=hat_pose(e, -7, 240, 100))


def pepper_freckles(d, c, e):
	s = ''
	for side in (-1, 1):
		for (dx, dy) in ((-12, 0), (0, 8), (12, 0), (2, -8)):
			s += C(240 + side * 102 + dx, 236 + dy, 2.6, fill=darker(c['shade'], 0.3), st=None, op=0.75)
	return s


PEPPER = dict(fur='#d9b27c', shade='#b48c58', muzzle='#eed3a5', inner='#a87a50', iris='#4fa35a', iris2='#163f1d',
	lashes=2, mouth='grin', ears=(116, 100, 36), brow_raise=True,
	outfit=pepper_outfit, neck=pepper_neck, hat=pepper_hat, fur_face=pepper_freckles,
	fx_sparkle=[(88, 160, 14), (392, 176, 12), (100, 212, 8)])


# ---------------------------------------------------------------------------- DUCHESS VELVETEEN (fashion designer)

STRAW = '#ecdcf3'
PLUM = '#6a3d8f'


def duchess_back(d, c, e):
	k = d.clip('M50,86 A190,46 0 1 0 430,86 A190,46 0 1 0 50,86 Z')
	s = E(240, 86, 190, 46, fill=STRAW, st=None)
	s += G(E(260, 100, 190, 46, fill='#cdb5de', st=None) + E(236, 82, 186, 42, fill=STRAW, st=None) +
		E(240, 86, 150, 34, st='#d8c3e6', sw=3) + E(240, 86, 120, 27, st='#d8c3e6', sw=3), clip=k)
	s += E(240, 86, 190, 46, st=OUT, sw=SW)
	return G(s, tf=hat_pose(e, -3, 240, 100, 0))


def duchess_hat(d, c, e):
	s = ''
	# front lip of the brim
	lip = 'M50,86 C62,124 150,132 240,132 C330,132 418,124 430,86 C392,108 320,114 240,114 C160,114 88,108 50,86 Z'
	s += P(lip, fill='#dcc6ea', st=OUT, sw=5)
	s += P('M80,104 C140,122 340,122 400,104', st=WHITE, sw=3, op=0.5)
	# crown
	crown = 'M164,108 C160,46 196,22 240,22 C284,22 320,46 316,108 Z'
	k = d.clip(crown)
	s += P(crown, fill=STRAW, st=None) + G(E(290, 70, 50, 60, fill='#cdb5de', st=None), clip=k) + P(crown, st=OUT, sw=SW)
	band = 'M166,84 C200,94 280,94 314,84 L316,108 C280,118 200,118 164,108 Z'
	s += P(band, fill=PLUM, st=OUT, sw=4.5)
	# feather plume
	fe = smooth([(298, 94), (328, 62), (372, 40), (430, 34), (408, 56), (368, 80), (324, 98)])
	kf = d.clip(fe)
	barbs = ''
	for i in range(1, 9):
		t = i / 9.0
		x, y = 300 + (428 - 300) * t, 92 - (92 - 36) * (t ** 0.8)
		barbs += P('M%s L%s' % (pt((x, y)), pt((x + 6, y - 18))), st='#d7c2e6', sw=2.5) + P('M%s L%s' % (pt((x, y)), pt((x + 16, y + 6))), st='#d7c2e6', sw=2.5)
	s += P(fe, fill='#fffaf0', st=None) + G(barbs + E(420, 42, 32, 22, fill='#b98fd8', st=None, op=0.75), clip=kf) + P(fe, st=OUT, sw=4.5)
	s += P('M300,94 Q360,52 428,36', st='#bfa4d4', sw=3)
	# bow on the band
	s += P('M314,96 L340,82 L342,112 Z', fill=PLUM, st=OUT, sw=4) + P('M314,96 L292,84 L290,110 Z', fill=PLUM, st=OUT, sw=4)
	s += C(314, 96, 7, fill='#8a55b5', st=OUT, sw=3.5)
	return G(s, tf=hat_pose(e, -3, 240, 100, 0))


def duchess_outfit(d, c, e):
	shawl = '#c4a2df'
	s = R(-40, 280, 560, 380, fill=shawl, st=None)
	s += P('M198,322 C192,372 186,412 184,440 L296,440 C294,412 288,372 282,322 Z', fill=c['fur'], st=None)
	s += P('M184,430 Q212,404 240,424 Q268,404 296,430 L304,640 L176,640 Z', fill=PLUM, st=OUT, sw=4)
	s += P('M240,424 L240,640', st=darker(PLUM, 0.3), sw=3, op=0.6)
	for side in (-1, 1):
		edge = 'M%s C%s %s %s' % (pt((240 + side * 42, 320)), pt((240 + side * 52, 380)), pt((240 + side * 62, 460)), pt((240 + side * 70, 640)))
		s += P(edge, st=OUT, sw=5)
		s += fold('M%s C%s %s %s' % (pt((240 + side * 110, 350)), pt((240 + side * 120, 420)), pt((240 + side * 118, 500)), pt((240 + side * 130, 640))), OUT, 3.5, 0.3)
		s += fold('M%s C%s %s %s' % (pt((240 + side * 150, 380)), pt((240 + side * 160, 440)), pt((240 + side * 158, 520)), pt((240 + side * 168, 640))), OUT, 3.5, 0.25)
	return s


def duchess_neck(d, c, e):
	s = ''
	pts = resample(sample_smooth([(186, 328), (212, 352), (240, 360), (268, 352), (294, 328)], 10), 11)
	for (x, y) in pts:
		s += C(x, y, 7.5, fill='#fbf8f2', st=OUT, sw=2.5) + C(x - 2.4, y - 2.4, 2.4, fill=WHITE, st=None) + C(x + 2, y + 2.5, 3, fill='#d9d2e0', st=None, op=0.7)
	s += P(drop(240, 382, 9), fill='#9b59d0', st=OUT, sw=3) + C(237, 380, 2.5, fill=WHITE, st=None, op=0.8)
	return s


def duchess_face(d, c, e):
	return C(300, 292, 3.6, fill=OUT, st=None)


DUCHESS = dict(fur='#f2e3c6', shade='#d6bf98', muzzle='#fcf3df', inner='#d9a89a', iris='#9a6dc8', iris2='#341a52',
	lid=0.36, lid_slant=-2, lashes=3, mouth='smirk', ears=False, tilt=-3, arms=False, blush_op=0.22,
	back=duchess_back, hat=duchess_hat, outfit=duchess_outfit, neck=duchess_neck, face=duchess_face,
	fx_sweat=(374, 162), fx_lines=(96, 150), fx_anger=(360, 160),
	fx_sparkle=[(80, 170, 14), (400, 176, 12), (98, 222, 8)])


# ---------------------------------------------------------------------------- BRAMBLE THISTLEWOOD (gardener)

OVERALL = '#5f9d48'


def flower(x, y, r, col, center='#ffcf3a'):
	s = ''
	for i in range(5):
		a = math.radians(-90 + i * 72)
		s += C(x + math.cos(a) * r * 0.55, y + math.sin(a) * r * 0.55, r * 0.52, fill=col, st=OUT, sw=2.6)
	for i in range(5):
		a = math.radians(-90 + i * 72)
		s += C(x + math.cos(a) * r * 0.55, y + math.sin(a) * r * 0.55, r * 0.4, fill=col, st=None)
	s += C(x, y, r * 0.32, fill=center, st=OUT, sw=2.2)
	return s


def leaf(x, y, ln, ang, col='#5bb04a'):
	d_ = 'M%s Q%s %s Q%s %s Z' % (pt((0, 0)), pt((ln * 0.5, -ln * 0.38)), pt((ln, 0)), pt((ln * 0.5, ln * 0.38)), pt((0, 0)))
	return '<g transform="translate(%s %s) rotate(%s)">%s%s</g>' % (n(x), n(y), n(ang), P(d_, fill=col, st=OUT, sw=2.6),
		P('M%s L%s' % (pt((2, 0)), pt((ln * 0.8, 0))), st='#3a7d2e', sw=1.8))


def bramble_hat(d, c, e):
	vine = 'M118,110 C146,80 196,64 240,64 C284,64 334,80 362,110'
	s = P(vine, st=OUT, sw=11) + P(vine, st='#4f8a3a', sw=6)
	for (x, y, ln, a) in ((132, 92, 26, -150), (178, 72, 24, -120), (222, 64, 22, -70), (262, 62, 24, -100), (304, 70, 24, -60), (350, 92, 26, -30)):
		s += leaf(x, y, ln, a)
	cols = ['#ff8fb1', '#fff4e0', '#ffd54f', '#b9a0e6', '#ff9f43', '#ff8fb1', '#fff4e0']
	for i, (x, y, r) in enumerate(((122, 106, 19), (156, 80, 21), (198, 66, 20), (240, 60, 24), (282, 66, 20), (324, 80, 21), (358, 106, 19))):
		s += flower(x, y, r, cols[i], '#ffb020' if cols[i] != '#ffd54f' else '#ff8a3d')
	return G(s, tf=hat_pose(e, 0, 240, 100, 10))


def bramble_outfit(d, c, e):
	s = R(-40, 280, 560, 380, fill='#f6edd0', st=None)
	ov = ('M180,396 L300,396 L304,640 L176,640 Z')
	s += P(ov, fill=OVERALL, st=OUT, sw=4.5)
	s += P('M206,430 L274,430 L272,478 Q240,486 208,478 Z', fill=darker(OVERALL, 0.15), st=OUT, sw=3.5)
	s += P('M210,436 L270,436', st='#d6f0b8', sw=2, op=0.7, extra=' stroke-dasharray="4 3"')
	s += leaf(232, 432, 22, -70, '#7cc65d')
	for side in (-1, 1):
		strap = 'M%s C%s %s %s L%s C%s %s %s Z' % (pt((240 + side * 52, 404)), pt((240 + side * 70, 370)), pt((240 + side * 92, 336)), pt((240 + side * 112, 316)),
			pt((240 + side * 140, 322)), pt((240 + side * 114, 350)), pt((240 + side * 86, 392)), pt((240 + side * 76, 410)))
		s += P(strap, fill=OVERALL, st=OUT, sw=4.5)
		s += button(240 + side * 62, 408, 7, '#ffd54f')
	return s


def bramble_neck(d, c, e):
	s = ''
	for side in (-1, 1):
		s += P(smooth([(240 + side * 2, 342), (240 + side * 30, 330), (240 + side * 58, 322), (240 + side * 62, 348), (240 + side * 34, 366)]), fill='#fffaf0', st=OUT, sw=4)
	return s


def bramble_front(d, c, e):
	tilt = {'normal': 0, 'happy': -12, 'shock': 16, 'angry': -6, 'sad': 14}[e]
	s = ''
	blade = smooth([(98, 268), (114, 286), (122, 322), (114, 352), (100, 358), (88, 340), (86, 300)])
	g = d.lin([(0, '#f4f7fa'), (1, '#9aa6b2')], 0, 0, 1, 0)
	s += P(blade, fill=g, st=OUT, sw=4.5)
	s += P('M104,290 L104,344', st='#7b8794', sw=2.5)
	s += E(98, 330, 9, 6, fill='#6b4a2a', st=None, op=0.6)
	s += P('M104,356 L112,412', st=OUT, sw=17) + P('M104,356 L112,412', st='#b0743c', sw=11)
	s += paw(112, 404, c['fur'], 12, 25, 21)
	return G(s, tf=rot(tilt, 112, 420))


def bramble_dirt(d, c, e):
	return E(336, 262, 14, 8, fill='#5a3f1c', st=None, op=0.3, extra=' transform="%s"' % rot(-20, 336, 262)) + C(352, 252, 3, fill='#5a3f1c', st=None, op=0.3)


BRAMBLE = dict(fur='#8e7a4b', shade='#6c5a32', muzzle='#b19c6a', inner='#5c4a2a', iris='#62b34c', iris2='#1d4618',
	lid=0.18, lashes=2, mouth='smile', ears=(100, 82, 16),
	hat=bramble_hat, outfit=bramble_outfit, neck=bramble_neck, front=bramble_front, fur_face=bramble_dirt,
	fx_sparkle=[(82, 160, 14), (398, 176, 12), (96, 214, 8)])


# ---------------------------------------------------------------------------- PROFESSOR NIBS (chemist)

LAB = '#f6f8fa'


def nibs_outfit(d, c, e):
	s = R(-40, 280, 560, 380, fill=LAB, st=None)
	s += P('M196,326 L240,452 L284,326 Z', fill='#bcd6ef', st=None)
	for side in (-1, 1):
		lap = [(240 + side * 46, 322), (240 + side * 96, 334), (240 + side * 78, 376), (240 + side * 92, 392), (240 + side * 8, 486), (240 + side * 2, 456)]
		s += P(poly(lap), fill='#e2e8ee', st=OUT, sw=4.5)
	s += P('M240,456 L240,640', st=OUT, sw=4)
	s += button(254, 500, 6, '#dfe5ea') + button(254, 560, 6, '#dfe5ea')
	# breast pocket with pens and a test tube
	s += R(124, 408, 56, 52, rx=4, fill='#e8edf2', st=OUT, sw=4)
	s += R(134, 384, 8, 30, rx=3, fill='#3d6fd8', st=OUT, sw=2.5) + R(148, 388, 8, 26, rx=3, fill='#e04848', st=OUT, sw=2.5)
	s += R(161, 376, 12, 38, rx=6, fill='#dff6ff', st=OUT, sw=2.5) + R(162, 392, 10, 22, rx=5, fill='#6fe06a', st=None)
	return s


def nibs_neck(d, c, e):
	s = ''
	for side in (-1, 1):
		s += P(poly([(240 + side * 4, 342), (240 + side * 42, 326), (240 + side * 34, 360)]), fill='#dcebf8', st=OUT, sw=4)
	red = '#d84a4a'
	s += P('M240,350 L210,334 L208,370 Z', fill=red, st=OUT, sw=4) + P('M240,350 L270,334 L272,370 Z', fill=red, st=OUT, sw=4)
	for (x, y) in ((220, 346), (222, 360), (258, 346), (260, 360)):
		s += C(x, y, 2.6, fill=WHITE, st=None, op=0.85)
	s += R(231, 341, 18, 18, rx=5, fill='#b83434', st=OUT, sw=3.5)
	return s


def nibs_hat(d, c, e):
	s = ''
	# wild tuft of hair
	for (a, b, cc) in (((232, 74), (210, 44), (196, 46)), ((240, 72), (240, 36), (256, 26)), ((250, 74), (276, 46), (290, 52))):
		hd = 'M%s Q%s %s' % (pt(a), pt(b), pt(cc))
		s += P(hd, st=OUT, sw=12) + P(hd, st='#d8d0c4', sw=6)
	# goggles pushed up on the forehead
	strap = 'M108,104 Q240,78 372,104 L372,120 Q240,96 108,120 Z'
	s += P(strap, fill='#5a3a22', st=OUT, sw=4.5)
	for x in (196, 284):
		g = d.lin([(0, '#e6f8ff'), (0.55, '#8fd0ea'), (1, '#4a8fb4')])
		s += C(x, 98, 27, fill='#c98a3c', st=OUT, sw=5) + C(x, 98, 19, fill=g, st=OUT, sw=3)
		s += P('M%s Q%s %s' % (pt((x - 12, 92)), pt((x - 8, 84)), pt((x + 2, 82))), st=WHITE, sw=3.5, op=0.9)
		for k in range(6):
			a = math.radians(k * 60 + 30)
			s += C(x + math.cos(a) * 23, 98 + math.sin(a) * 23, 1.8, fill='#7a4f1c', st=None)
	s += R(224, 92, 32, 12, rx=5, fill='#c98a3c', st=OUT, sw=3.5)
	return G(s, tf=hat_pose(e, 0, 240, 100, 8))


NIBS = dict(fur='#958170', shade='#745f4e', muzzle='#b8a490', inner='#5e4a3c', iris='#6a97bd', iris2='#1f3a52',
	mouth='w', brow_raise=True, ears=(108, 92, 30),
	outfit=nibs_outfit, neck=nibs_neck, hat=nibs_hat,
	fx_sparkle=[(80, 160, 14), (400, 176, 12), (96, 214, 8)])


# ---------------------------------------------------------------------------- ZUZU BYTE (hacker)

CYAN = '#3ff0ff'
HOOD_K = '#2c2c36'


def zuzu_outfit(d, c, e):
	s = R(-40, 280, 560, 380, fill=HOOD_K, st=None)
	s += P('M240,372 L240,640', st='#14141a', sw=4)
	s += P('M156,530 Q240,512 324,530', st='#14141a', sw=4, op=0.8)
	# glowing sticker
	s += C(300, 424, 34, fill=CYAN, st=None, op=0.18)
	s += R(276, 400, 48, 48, rx=10, fill='#16233a', st=OUT, sw=4)
	px = ''
	for (x, y) in ((2, 0), (3, 0), (1, 1), (4, 1), (0, 2), (2, 2), (3, 2), (5, 2), (0, 3), (5, 3), (1, 4), (4, 4), (2, 5), (3, 5)):
		px += R(282 + x * 6, 406 + y * 6, 6, 6, fill=CYAN, st=None)
	s += px
	return s


def zuzu_neck(d, c, e):
	s = ''
	hood = smooth(sym([(240, 312), (316, 306), (368, 330), (372, 366), (330, 386), (240, 380)]))
	s += P(hood, fill='#383844', st=OUT, sw=5)
	s += P(smooth(sym([(240, 326), (302, 322), (340, 340), (332, 360), (240, 364)])), fill='#15151b', st=None, op=0.9)
	for (x0, x1, y1) in ((222, 214, 448), (258, 266, 442)):
		s += stroke2('M%s Q%s %s' % (pt((x0, 368)), pt((x0 - 2, 404)), pt((x1, y1))), CYAN, 4.5)
		s += R(x1 - 4, y1 - 2, 8, 14, rx=2, fill='#e8e8f0', st=OUT, sw=2.5)
	return s


def zuzu_hat(d, c, e):
	s = ''
	band = 'M112,190 C104,70 172,40 240,40 C308,40 376,70 368,190'
	for side in (-1, 1):
		ear = poly([(240 + side * 52, 58), (240 + side * 70, 20), (240 + side * 100, 66)])
		s += P(ear, fill='#30303a', st=OUT, sw=5)
		s += P(poly([(240 + side * 62, 56), (240 + side * 71, 34), (240 + side * 88, 60)]), fill=CYAN, st=None, op=0.9)
	s += P(band, st=OUT, sw=22) + P(band, st='#34343f', sw=14) + P('M128,150 C124,80 180,52 240,50', st='#5a5a68', sw=3.5, op=0.8)
	for side in (-1, 1):
		x = 240 + side * 128
		s += C(x, 196, 42, fill=CYAN, st=None, op=0.16)
		s += R(x - 22, 154, 44, 84, rx=20, fill='#2a2a33', st=OUT, sw=5)
		s += E(x + side * 2, 196, 12, 26, fill=CYAN, st=OUT, sw=3)
		s += E(x + side * 2, 196, 5, 15, fill=WHITE, st=None, op=0.7)
	return G(s, tf=hat_pose(e, 0, 240, 100, 10))


def zuzu_face(d, c, e):
	# little plaster on the cheek
	pl = R(-16, -7, 32, 14, rx=5, fill='#f6dcc0', st=OUT, sw=3) + R(-5, -6, 10, 12, fill='#e6c39e', st=None)
	pl += C(-10, -2, 1.3, fill='#b8916c', st=None) + C(10, 2, 1.3, fill='#b8916c', st=None)
	return '<g transform="translate(144 232) rotate(-24)">%s</g>' % pl


ZUZU = dict(fur='#716c6d', shade='#544f50', muzzle='#908a8a', inner='#3f3b3c', iris='#35e3f2', iris2='#0a4a55',
	lid=0.46, mouth='flat', ears=False, blush_op=0.18,
	outfit=zuzu_outfit, neck=zuzu_neck, hat=zuzu_hat, face=zuzu_face,
	fx_sweat=(350, 120), fx_lines=(124, 90), fx_anger=(336, 120),
	fx_sparkle=[(70, 120, 14), (410, 120, 12), (80, 260, 8)])


# ---------------------------------------------------------------------------- SIR REGINALD PUDDLESWORTH III (fencer)

BURGUNDY = '#7d1f3e'


def reginald_outfit(d, c, e):
	s = R(-40, 280, 560, 380, fill='#f8f8f2', st=None)
	s += P('M224,362 C262,420 300,500 320,640', st=OUT, sw=4.5)
	for t in (0.2, 0.42, 0.64):
		x = 224 + (320 - 224) * t + 8
		y = 362 + (640 - 362) * t
		s += button(x, y, 5, '#e8e8e0')
	for y in range(420, 640, 36):
		s += fold('M120,%d L180,%d' % (y, y + 10), OUT, 2.5, 0.15)
	# rosette medal
	s += P('M150,430 L140,470 L152,462 L158,474 L164,434 Z', fill='#2f5fb0', st=OUT, sw=3)
	s += C(154, 424, 15, fill='#d83b3b', st=OUT, sw=3) + C(154, 424, 8, fill=GOLD, st=OUT, sw=2.5)
	return s


def reginald_neck(d, c, e):
	col = 'M172,314 Q240,344 308,314 L310,346 Q240,378 170,346 Z'
	return P(col, fill='#f1f1ea', st=OUT, sw=5) + P('M180,340 Q240,368 300,340', st='#d4d4c8', sw=3)


def reginald_hat(d, c, e):
	s = ''
	# plume
	pl = smooth([(318, 74), (334, 46), (360, 30), (396, 28), (376, 46), (356, 64), (336, 82)])
	kp = d.clip(pl)
	barbs = ''
	for i in range(1, 8):
		t = i / 8.0
		x, y = 324 + (392 - 324) * t, 76 - 46 * (t ** 0.7)
		barbs += P('M%s L%s' % (pt((x, y)), pt((x - 10, y - 10))), st='#e3d9c4', sw=2.2) + P('M%s L%s' % (pt((x, y)), pt((x + 12, y + 2))), st='#e3d9c4', sw=2.2)
	s += P(pl, fill='#fffdf6', st=None) + G(barbs + E(390, 32, 18, 14, fill='#d83b3b', st=None, op=0.8), clip=kp) + P(pl, st=OUT, sw=4.5)
	# beret tilted to the left
	ber = smooth([(240, 46), (302, 46), (346, 60), (362, 84), (334, 100), (240, 106), (150, 104), (104, 94), (94, 72), (132, 54), (186, 46)])
	k = d.clip(ber)
	s += P(ber, fill=BURGUNDY, st=None)
	s += G(P(ber, fill='#5e1530', st=None, extra=' transform="translate(10 12)"') + P(ber, fill=BURGUNDY, st=None, extra=' transform="translate(-4 -4)"')
		+ E(170, 60, 40, 9, fill=WHITE, st=None, op=0.2), clip=k)
	s += P(ber, st=OUT, sw=SW)
	s += P('M120,94 Q240,114 350,92', st='#5e1530', sw=4)
	s += C(226, 44, 8, fill=BURGUNDY, st=OUT, sw=4)
	s += P(star(322, 84, 9, 0.45), fill=GOLD, st=OUT, sw=2.5)
	return G(s, tf=hat_pose(e, -4, 240, 100, 3))


def reginald_face(d, c, e):
	# dashing curled handlebar moustache
	dy = {'happy': -3, 'shock': -4, 'angry': 1, 'sad': 5}.get(e, 0)
	lift = {'happy': -6, 'shock': 4, 'angry': -2, 'sad': 8}.get(e, 0)
	s = ''
	for side in (-1, 1):
		m = smooth([(240, 246 + dy), (240 + side * 22, 244 + dy), (240 + side * 46, 250 + dy), (240 + side * 66, 240 + dy + lift),
			(240 + side * 70, 226 + dy + lift), (240 + side * 62, 222 + dy + lift), (240 + side * 58, 232 + dy + lift),
			(240 + side * 46, 260 + dy), (240 + side * 22, 262 + dy), (240, 256 + dy)])
		s += P(m, fill='#3a2410', st=OUT, sw=3.5)
		s += P('M%s Q%s %s' % (pt((240 + side * 12, 250 + dy)), pt((240 + side * 30, 248 + dy)), pt((240 + side * 44, 252 + dy))), st=WHITE, sw=2.2, op=0.35)
	return s


def reginald_front(d, c, e):
	tilt = {'normal': 0, 'happy': -6, 'shock': -3, 'angry': -12, 'sad': -1}[e]
	s = ''
	blade = 'M392,360 L444,34' if e != 'sad' else 'M392,360 L452,70'
	s += P(blade, st=OUT, sw=9) + P(blade, st='#dfe6ee', sw=4) + C(444 if e != 'sad' else 452, 34 if e != 'sad' else 70, 5, fill='#2a2a30', st=OUT, sw=3)
	g = d.rad([(0, WHITE), (0.6, '#c4ccd4'), (1, '#7d8794')], cx=0.35, cy=0.35, r=0.7)
	s += E(390, 372, 30, 14, fill=g, st=OUT, sw=4.5, extra=' transform="%s"' % rot(-10, 390, 372))
	s += P('M388,380 L394,426', st=OUT, sw=15) + P('M388,380 L394,426', st='#3a2a22', sw=9)
	s += paw(392, 414, c['fur'], 8, 26, 22, glove='#fbfbf6')
	return G(s, tf=rot(tilt, 392, 430))


REGINALD = dict(fur='#cf9447', shade='#a8722f', muzzle='#e6b676', inner='#8a5a28', iris='#d29420', iris2='#5a3404',
	lid=0.22, mouth='w', ears=(116, 102, 36), tilt=-2, brow='#3a2410',
	outfit=reginald_outfit, neck=reginald_neck, hat=reginald_hat, face=reginald_face, front=reginald_front,
	fx_sweat=(370, 150), fx_lines=(96, 130),
	fx_sparkle=[(80, 160, 14), (98, 222, 8), (360, 230, 9)])


# ---------------------------------------------------------------------------- GRUB PEMBERTON (chef)


def grub_hat(d, c, e):
	s = ''
	band = 'M176,100 L182,58 L298,58 L304,100 Q240,110 176,100 Z'
	puffs = [(178, 46, 28), (214, 30, 29), (266, 30, 29), (302, 46, 28), (240, 40, 31)]
	for (x, y, r) in puffs:
		s += C(x, y, r, fill='#fbfbf8', st=OUT, sw=12)
	for (x, y, r) in puffs:
		s += C(x, y, r, fill='#fbfbf8', st=None)
	for (x, y, r) in puffs[:4]:
		s += P('M%s Q%s %s' % (pt((x - r * 0.6, y + r * 0.5)), pt((x, y + r * 0.85)), pt((x + r * 0.6, y + r * 0.5))), st='#d6dbe2', sw=5, op=0.9)
	s += P(band, fill='#f4f4f0', st=OUT, sw=5.5)
	for x in (202, 222, 240, 258, 278):
		s += P('M%s L%s' % (pt((x, 64)), pt((x + (x - 240) * 0.04, 100))), st='#cfd5dc', sw=3)
	return G(s, tf=hat_pose(e, 3, 240, 100, 3))


def grub_outfit(d, c, e):
	s = R(-40, 280, 560, 380, fill='#fafaf6', st=None)
	s += P('M268,360 C262,420 262,520 266,640', st=OUT, sw=4)
	for y in (400, 452, 504, 556):
		s += button(212, y, 6.5, '#7a4a28') + button(296, y, 6.5, '#7a4a28')
	s += fold('M150,380 Q160,480 150,640', OUT, 3, 0.18)
	return s


def grub_neck(d, c, e):
	org = '#ff7a3d'
	s = P('M170,322 Q240,350 310,322 L314,346 Q240,380 166,346 Z', fill='#f1f1ec', st=OUT, sw=5)
	s += P(smooth([(196, 344), (240, 360), (284, 344), (276, 366), (240, 376), (204, 366)]), fill=org, st=OUT, sw=4.5)
	s += P('M226,364 L214,404 L238,392 Z', fill=darker(org, 0.12), st=OUT, sw=4) + P('M254,364 L266,404 L242,392 Z', fill=darker(org, 0.12), st=OUT, sw=4)
	s += C(240, 366, 9, fill=org, st=OUT, sw=4)
	return s


def grub_front(d, c, e):
	tilt = {'normal': 0, 'happy': -14, 'shock': 18, 'angry': -8, 'sad': 16}[e]
	s = ''
	wood = '#c98b4a'
	s += P('M100,330 L110,420', st=OUT, sw=15) + P('M100,330 L110,420', st=wood, sw=9)
	s += E(96, 300, 24, 32, fill=wood, st=OUT, sw=5, extra=' transform="%s"' % rot(-6, 96, 300))
	s += E(94, 296, 14, 20, fill='#a86a32', st=None, extra=' transform="%s"' % rot(-6, 94, 296))
	s += E(98, 306, 10, 8, fill='#ff9a3c', st=OUT, sw=2.5)
	s += E(90, 290, 4, 6, fill=WHITE, st=None, op=0.5)
	if e == 'happy':
		s += fx_steam(88, 262, 0.9)
	s += paw(110, 410, c['fur'], 10, 26, 22)
	return G(s, tf=rot(tilt, 110, 430))


GRUB = dict(fur='#b47538', shade='#925b26', muzzle='#d3a063', inner='#7a4a20', iris='#9a5a24', iris2='#2e1708',
	cheek=14, bw=1.12, mouth='smile', blush_op=0.4, ears=(104, 92, 24), hy=6,
	hat=grub_hat, outfit=grub_outfit, neck=grub_neck, front=grub_front,
	fx_sparkle=[(392, 160, 15), (380, 222, 9), (408, 110, 9)])


# ---------------------------------------------------------------------------- OLD MAN TUMBLE (napper)


def tumble_outline(d, c, e, hp):
	s = ''
	fur = lighter(c['fur'], 0.35)
	tufts = []
	for side in (-1, 1):
		for (y, ln) in ((200, 16), (232, 20), (264, 16)):
			x0 = 240 + side * 132
			tufts.append(smooth([(x0 - side * 8, y - 16), (x0 + side * ln * 0.6, y - 10), (x0 + side * ln, y + 2), (x0 + side * ln * 0.4, y + 6),
				(x0 - side * 6, y + 14)]))
	for t in tufts:
		s += P(t, fill=fur, st=OUT, sw=4.5)
	s += P(hp, st=OUT, sw=SIL)
	# fluffy chin beard
	beard = smooth([(198, 318), (240, 332), (282, 318), (280, 346), (264, 364), (252, 356), (240, 372), (228, 356), (216, 364), (200, 346)])
	s += P(beard, fill='#f3f0ea', st=OUT, sw=4.5)
	s += P('M224,340 Q232,352 230,360 M256,340 Q248,352 250,360', st='#cfc9bf', sw=2.5)
	return s


def tumble_face(d, c, e):
	s = ''
	if e != 'shock':
		for side in (-1, 1):
			cx = 240 + side * EYE_DX
			s += P('M%s Q%s %s' % (pt((cx - 14, EYE_Y + 30)), pt((cx, EYE_Y + 37)), pt((cx + 14, EYE_Y + 30))), st=OUT, sw=3, op=0.45)
	return s


def tumble_hat(d, c, e):
	blue = '#4f6fb0'
	droop = {'normal': 0, 'happy': -8, 'shock': -26, 'angry': -4, 'sad': 14}[e]
	tip = (412, 214 + droop)
	cone = smooth([(132, 102), (148, 58), (194, 28), (262, 18), (332, 32), (386, 78), (408, 140 + droop * 0.4), tip,
		(394, 196 + droop * 0.8), (376, 146 + droop * 0.3), (350, 104), (240, 86)])
	k = d.clip(cone)
	s = P(cone, fill=blue, st=None)
	inner = P(cone, fill='#3a5590', st=None, extra=' transform="translate(14 10)"') + P(cone, fill=blue, st=None, extra=' transform="translate(-4 -4)"')
	for (x, y) in ((170, 64), (220, 40), (276, 36), (330, 58), (372, 100), (396, 160), (250, 72), (306, 84), (196, 80)):
		inner += C(x, y, 7, fill='#f4f1ea', st=None, op=0.95)
	s += G(inner, clip=k) + P(cone, st=OUT, sw=SW)
	cuff = 'M124,104 C160,82 200,76 240,76 C280,76 320,82 356,104 L360,128 C320,106 280,100 240,100 C200,100 160,106 120,128 Z'
	s += P(cuff, fill='#f4f1ea', st=OUT, sw=5.5)
	s += P('M140,112 C190,92 290,92 340,112', st='#d6d1c6', sw=3)
	pom = []
	for i in range(14):
		a = math.radians(i * 360 / 14.0)
		rr = 22 if i % 2 == 0 else 17
		pom.append((tip[0] + math.cos(a) * rr, tip[1] + 8 + math.sin(a) * rr))
	s += P(smooth(pom), fill='#f8f6f0', st=OUT, sw=4.5)
	return G(s, tf=hat_pose(e, 0, 240, 100, 8))


def tumble_outfit(d, c, e):
	s = R(-40, 280, 560, 380, fill='#b9d3ec', st=None)
	for x in range(150, 340, 22):
		s += R(x, 280, 7, 360, fill='#8fb2d6', st=None)
	s += P('M206,330 L240,380 L274,330', st=OUT, sw=4)
	s += button(240, 410, 5, '#f4f1ea') + button(240, 450, 5, '#f4f1ea')
	plaid = '#c4553f'
	for side in (-1, 1):
		sh = smooth([(240 + side * 30, 316), (240 + side * 110, 316), (240 + side * 172, 356), (240 + side * 196, 440), (240 + side * 204, 640),
			(240 + side * 92, 640), (240 + side * 76, 520), (240 + side * 56, 410), (240 + side * 38, 350)])
		k = d.clip(sh)
		inner = P(sh, fill=plaid, st=None)
		for x in range(0, 480, 46):
			inner += R(x, 280, 16, 380, fill='#9e3b2b', st=None, op=0.6)
			inner += R(x + 26, 280, 3, 380, fill='#f2d8a8', st=None, op=0.8)
		for y in range(300, 640, 46):
			inner += R(-40, y, 560, 16, fill='#9e3b2b', st=None, op=0.5)
			inner += R(-40, y + 26, 560, 3, fill='#f2d8a8', st=None, op=0.8)
		s += G(inner, clip=k) + P(sh, st=OUT, sw=5)
	return s


TUMBLE = dict(fur='#cbc5bd', shade='#a49d94', muzzle='#e2ddd6', inner='#8f8279', iris='#7a7aa8', iris2='#2a2a44',
	lid=0.56, lid_slant=-3, bushy=True, brow='#f4f1ea', mouth='w', ears=(116, 108, 40), arms=False,
	hat=tumble_hat, outfit=tumble_outfit, outline=tumble_outline, face=tumble_face,
	fx_sweat=(106, 150), fx_lines=(100, 96), fx_anger=(118, 150),
	fx_sparkle=[(80, 150, 14), (96, 214, 8), (300, 2, 0.1)])


# ---------------------------------------------------------------------------- MARIGOLD FERN (nurse)

SCRUB = '#8fcbea'


def marigold_outfit(d, c, e):
	s = R(-40, 280, 560, 380, fill=SCRUB, st=None)
	s += P('M196,320 L240,408 L284,320', st=OUT, sw=13) + P('M196,320 L240,408 L284,320', st='#5ea6cc', sw=7)
	s += R(286, 430, 52, 46, rx=4, fill='#7fbfe0', st=OUT, sw=3.5)
	s += R(298, 410, 8, 30, rx=3, fill='#ff6f6f', st=OUT, sw=2.5) + R(310, 414, 8, 26, rx=3, fill=WHITE, st=OUT, sw=2.5)
	return s


def marigold_neck(d, c, e):
	tube = '#4b5660'
	s = ''
	t1 = 'M176,322 C168,360 176,404 196,430'
	t2 = 'M304,322 C314,356 312,388 294,410'
	s += P(t1, st=OUT, sw=11) + P(t1, st=tube, sw=6.5) + P(t2, st=OUT, sw=11) + P(t2, st=tube, sw=6.5)
	g = d.rad([(0, WHITE), (0.6, '#c4ccd4'), (1, '#7d8794')], cx=0.35, cy=0.35, r=0.7)
	s += C(200, 440, 17, fill=g, st=OUT, sw=4.5) + C(200, 440, 8, fill='#9aa5b0', st=OUT, sw=2.5)
	s += P('M294,410 L282,426 M294,410 L306,428', st=OUT, sw=7) + P('M294,410 L282,426 M294,410 L306,428', st='#c4ccd4', sw=3.5)
	s += C(282, 428, 4.5, fill='#2a2a30', st=None) + C(306, 430, 4.5, fill='#2a2a30', st=None)
	return s


def marigold_hat(d, c, e):
	capd = 'M186,100 L196,54 Q240,42 284,54 L294,100 Q240,110 186,100 Z'
	k = d.clip(capd)
	s = P(capd, fill='#fbfbf8', st=None) + G(R(150, 80, 200, 40, fill='#dfe5ea', st=None), clip=k) + P(capd, st=OUT, sw=5.5)
	s += P('M188,82 Q240,92 292,82', st=OUT, sw=3.5)
	s += P('M234,52 L246,52 L246,62 L256,62 L256,74 L246,74 L246,84 L234,84 L234,74 L224,74 L224,62 L234,62 Z', fill='#2fb06c', st=OUT, sw=2.5)
	for side in (-1, 1):
		s += P(poly([(240 + side * 46, 58), (240 + side * 62, 74), (240 + side * 52, 98)]), fill='#eef1f4', st=OUT, sw=3.5)
	return G(s, tf=hat_pose(e, -5, 240, 100, 12))


MARIGOLD = dict(fur='#d98b55', shade='#b66d3a', muzzle='#eeb383', inner='#a35a32', iris='#33b98c', iris2='#0e4a36',
	lashes=2, mouth='smile', ears=(100, 82, 16),
	outfit=marigold_outfit, neck=marigold_neck, hat=marigold_hat,
	fx_sparkle=[(82, 150, 14), (398, 176, 12), (96, 214, 8)])


# ---------------------------------------------------------------------------- FENNEL DAUBER (painter)

BERET = '#d83b3b'
SCARF = '#f2b632'
SCARF2 = '#2a9d8f'


def fennel_back(d, c, e):
	# paintbrush tucked behind the left ear
	s = ''
	h = 'M176,128 L104,30'
	s += P(h, st=OUT, sw=13) + P(h, st='#c88a4a', sw=8)
	s += P('M112,42 L100,26', st=OUT, sw=15) + P('M112,42 L100,26', st='#c9d0d8', sw=10)
	tipd = smooth([(102, 28), (88, 14), (80, -2), (96, 6), (108, 18)])
	s += P(tipd, fill='#3a7bd5', st=OUT, sw=4)
	return s


def fennel_smudges(d, c, e):
	s = ''
	for (x, y, r, col, a) in ((194, 106, 11, '#3a7bd5', 20), (346, 210, 10, '#ffd23c', -30), (300, 312, 7, '#4fbf6a', 0), (128, 250, 9, '#ff6fae', 40)):
		blob = smooth([(x - r, y), (x - r * 0.3, y - r * 0.9), (x + r * 0.8, y - r * 0.7), (x + r * 1.1, y + r * 0.2), (x + r * 0.2, y + r * 0.8), (x - r * 0.7, y + r * 0.6)])
		s += P(blob, fill=col, st=None, op=0.85) + C(x + r * 1.6, y + r * 0.6, r * 0.3, fill=col, st=None, op=0.85)
	return s


def fennel_hat(d, c, e):
	ber = smooth([(240, 46), (292, 42), (350, 54), (390, 78), (384, 98), (330, 104), (240, 106), (160, 102), (122, 92), (128, 66), (176, 50)])
	k = d.clip(ber)
	s = P(ber, fill=BERET, st=None)
	s += G(P(ber, fill='#a82828', st=None, extra=' transform="translate(10 12)"') + P(ber, fill=BERET, st=None, extra=' transform="translate(-4 -4)"')
		+ E(200, 58, 44, 9, fill=WHITE, st=None, op=0.22), clip=k)
	s += P(ber, st=OUT, sw=SW)
	s += P('M252,44 Q256,30 266,26', st=OUT, sw=9) + P('M252,44 Q256,30 266,26', st=BERET, sw=4.5)
	return G(s, tf=hat_pose(e, 7, 240, 100, 12))


def fennel_outfit(d, c, e):
	s = R(-40, 280, 560, 380, fill='#e6edf2', st=None)
	s += P('M200,330 Q240,350 280,330', st=OUT, sw=3, op=0.4)
	for (x, y, r, col) in ((140, 440, 9, '#3a7bd5'), (156, 456, 4, '#3a7bd5'), (330, 480, 10, '#d83b3b'), (300, 540, 7, '#ffd23c'),
		(180, 560, 9, '#4fbf6a'), (380, 420, 6, '#ff6fae'), (110, 520, 5, '#ffd23c')):
		s += C(x, y, r, fill=col, st=None, op=0.9)
	for x in (200, 240, 280):
		s += fold('M%d,360 L%d,420' % (x, x + (x - 240) * 0.2), OUT, 3, 0.25)
	return s


def fennel_neck(d, c, e):
	s = ''
	flow = {'normal': 0, 'happy': -14, 'shock': -26, 'angry': 8, 'sad': 30}[e]
	# flowing scarf tail over the left shoulder
	tail = smooth([(192, 338), (140, 326), (84, 300 + flow), (34, 296 + flow * 1.3), (54, 330 + flow), (100, 356 + flow * 0.5), (170, 372)])
	k = d.clip(tail)
	s += P(tail, fill=SCARF, st=None) + G(''.join(R(x, 200, 12, 300, fill=SCARF2, st=None, extra=' transform="%s"' % rot(-20, x, 330)) for x in (60, 100, 140)), clip=k)
	s += P(tail, st=OUT, sw=5)
	for i in range(4):
		y0 = 300 + flow * 1.3 + i * 8
		s += P('M%s L%s' % (pt((38 + i * 4, y0)), pt((24 + i * 4, y0 + 4))), st=OUT, sw=3)
	wrap = smooth([(168, 318), (240, 340), (312, 318), (322, 344), (302, 370), (240, 382), (178, 370), (158, 344)])
	kw = d.clip(wrap)
	s += P(wrap, fill=SCARF, st=None) + G(''.join(R(x, 300, 12, 100, fill=SCARF2, st=None, extra=' transform="%s"' % rot(16, x, 350)) for x in (180, 222, 264, 306)), clip=kw)
	s += P(wrap, st=OUT, sw=5)
	# hanging end
	end = smooth([(282, 360), (312, 366), (320, 430), (326, 470), (296, 476), (286, 420)])
	ke = d.clip(end)
	s += P(end, fill=SCARF, st=None) + G(R(270, 400, 80, 12, fill=SCARF2, st=None) + R(270, 440, 80, 12, fill=SCARF2, st=None), clip=ke) + P(end, st=OUT, sw=5)
	return s


FENNEL = dict(fur='#c49b6d', shade='#a07a4f', muzzle='#dcbc93', inner='#8a6040', iris='#3f86e0', iris2='#14305e',
	lid=0.14, mouth='smile', ears=(100, 82, 16),
	back=fennel_back, fur_face=fennel_smudges, hat=fennel_hat, outfit=fennel_outfit, neck=fennel_neck,
	fx_sparkle=[(84, 160, 14), (400, 170, 12), (96, 214, 8)], fx_sweat=(372, 160))


# ============================================================================ WARDEN SNAPJAW (robotic caiman)

SJ_G = '#4caf50'
SJ_GD = '#2e7d32'
SJ_GL = '#86d47f'
SJ_BELLY = '#d8e9a4'
SJ_RED = '#ff2a2a'

# grin line = lower edge of the upper jaw, from the right cheek round the snout tip to the left cheek
SJ_MOUTH = [(380, 204), (366, 244), (340, 282), (306, 316), (272, 338), (240, 344), (208, 338), (174, 316), (140, 282), (114, 244), (100, 204)]
SJ_TOP = [(100, 204), (94, 168), (104, 136), (122, 108), (140, 82), (178, 66), (216, 82), (230, 108), (240, 122), (250, 108), (264, 82),
	(302, 66), (340, 82), (358, 108), (376, 136), (386, 168)]
SJ_EYE_L = (178, 116)
SJ_EYE_R = (302, 116)


def sj_outfit(d, c, e):
	s = R(-40, 280, 560, 380, fill='#1d1a24', st=None)
	s += P('M200,322 L240,452 L280,322 Z', fill='#f6f4f0', st=None)
	for side in (-1, 1):
		lap = [(240 + side * 40, 318), (240 + side * 100, 330), (240 + side * 84, 380), (240 + side * 100, 398), (240 + side * 10, 490), (240 + side * 4, 456)]
		s += P(poly(lap), fill='#34303e', st=OUT, sw=4.5)
		s += P('M%s L%s' % (pt((240 + side * 80, 344)), pt((240 + side * 20, 470))), st=WHITE, sw=3, op=0.18)
	s += button(240, 470, 6, '#c9a13c') + button(240, 520, 6, '#c9a13c')
	# warden badge + red pocket square
	s += P(star(158, 430, 20, 0.5), fill='#f2c14e', st=OUT, sw=3.5) + C(158, 430, 6, fill='#d9a72e', st=OUT, sw=2)
	s += P('M310,420 L346,414 L340,430 L332,422 L322,432 L316,422 Z', fill='#d32f2f', st=OUT, sw=3)
	s += R(306, 426, 46, 8, fill='#121018', st=OUT, sw=2.5)
	return s


def sj_neck(d, c, e):
	s = ''
	for side in (-1, 1):
		s += P(poly([(240 + side * 6, 372), (240 + side * 44, 352), (240 + side * 38, 392)]), fill='#f6f4f0', st=OUT, sw=4)
	red = '#d32f2f'
	s += P('M240,384 L200,362 L198,410 Z', fill=red, st=OUT, sw=4.5) + P('M240,384 L280,362 L282,410 Z', fill=red, st=OUT, sw=4.5)
	s += P('M206,374 L222,384 M274,374 L258,384', st='#9a1f1f', sw=3)
	s += R(228, 372, 24, 24, rx=7, fill='#b71c1c', st=OUT, sw=4)
	return s


def sj_teeth(line_pts, size, outward=True, offset=0.0, count=None):
	"""white triangular teeth along a polyline; outward=True points away from the head centre"""
	pts = sample_smooth(line_pts, 10)
	cnt = count or 15
	ev = resample(pts, cnt * 2 + 1)
	s = ''
	for i in range(cnt):
		a = ev[i * 2 + (1 if offset else 0)]
		b = ev[min(i * 2 + 1 + (1 if offset else 0), len(ev) - 1)]
		m = ((a[0] + b[0]) / 2.0, (a[1] + b[1]) / 2.0)
		tx, ty = b[0] - a[0], b[1] - a[1]
		ln = math.hypot(tx, ty) or 1
		nx, ny = -ty / ln, tx / ln
		# point the normal away from (240, 200)
		if (m[0] + nx - 240) ** 2 + (m[1] + ny - 200) ** 2 < (m[0] - 240) ** 2 + (m[1] - 200) ** 2:
			nx, ny = -nx, -ny
		if not outward:
			nx, ny = -nx, -ny
		h = size * (0.75 + 0.25 * math.sin(i * 1.7))
		tip = (m[0] + nx * h, m[1] + ny * h)
		s += P(poly([(a[0] - tx * 0.05, a[1] - ty * 0.05), tip, (b[0] + tx * 0.05, b[1] + ty * 0.05)]), fill='#fbfbf2', st=OUT, sw=2.6)
	return s


def sj_split(d, body_d, green, chrome):
	"""fill a path with the green (left) and chrome (right) halves"""
	kl = d.clip('M-100,-100 L240,-100 L240,700 L-100,700 Z')
	kr = d.clip('M240,-100 L600,-100 L600,700 L240,700 Z')
	return G(green, clip=kl) + G(chrome, clip=kr)


def sj_scales(d, k, x0, x1, y0, y1, step=22):
	s = ''
	row = 0
	y = y0
	while y < y1:
		off = (step / 2.0) if row % 2 else 0
		x = x0 + off
		while x < x1:
			s += P('M%s Q%s %s' % (pt((x - step * 0.45, y)), pt((x, y + step * 0.62)), pt((x + step * 0.45, y))), st=SJ_GD, sw=2.6, op=0.55)
			x += step
		y += step * 0.62
		row += 1
	return G(s, clip=k)


def sj_chrome(d):
	# harsh banded chrome: hard-stop highlight stripes instead of a soft sheen
	return d.lin([(0, '#ffffff'), (0.15, '#e6ebf0'), (0.16, '#a3aeb9'), (0.4, '#7a8693'), (0.41, '#56616e'), (0.58, '#6c7885'),
		(0.59, '#f2f6fa'), (0.68, '#ffffff'), (0.69, '#97a3af'), (1, '#4c5763')], user=(240, 0, 384, 0))


def sj_chrome_v(d):
	return d.lin([(0, '#eef2f6'), (0.5, '#a8b3be'), (1, '#6f7b88')], user=(0, 300, 0, 420))


def snapjaw_eye_green(d, e):
	x, y = SJ_EYE_L
	s = ''
	rx, ry = 21, 23
	if e == 'happy':
		s += P('M%s Q%s %s' % (pt((x - rx, y + 8)), pt((x, y - ry * 1.05)), pt((x + rx, y + 8))), st=OUT, sw=8)
		return s
	if e == 'shock':
		s += E(x, y, rx * 1.12, ry * 1.12, fill='#fffbe0', st=OUT, sw=5)
		s += E(x, y + 1, 3.2, 10, fill=OUT, st=None)
		return s
	g = d.lin([(0, '#fff07a'), (0.6, '#ffc21f'), (1, '#e88a00')])
	core = E(x, y, rx, ry, fill=OUT, st=None) + E(x, y + 1.5, rx - 4, ry - 4.5, fill=g, st=None)
	slit = 2.2 if e == 'angry' else 4.2
	core += E(x, y + 2, slit, ry - 7, fill='#140a05', st=None)
	core += E(x - 7, y - 8, 5.5, 4.5, fill=WHITE, st=None) + C(x + 7, y + 9, 2.6, fill=WHITE, st=None)
	if e == 'sad':
		core += E(x, y + ry * 0.62, rx * 0.8, ry * 0.3, fill='#a8e4ff', st=None, op=0.85)
	lid, slant = {'normal': (0.44, -3), 'angry': (0.36, 10), 'sad': (0.3, -9)}[e]
	y0 = y - ry + lid * 2 * ry
	f = lid_line_y(x, rx, -1, y0, slant)
	xa, xb = x - rx - 12, x + rx + 12
	clip = d.clip(poly([(xa, f(xa)), (xb, f(xb)), (xb, y + ry + 20), (xa, y + ry + 20)]))
	s += G(core, clip=clip)
	xs = [x - rx + i * (2 * rx) / 40.0 for i in range(41)]
	inside = [xx for xx in xs if ((xx - x) / rx) ** 2 + ((f(xx) - y) / ry) ** 2 <= 1.0]
	if inside:
		x1, x2 = inside[0] - 3, inside[-1] + 3
		s += P('M%s L%s' % (pt((x1, f(x1))), pt((x2, f(x2)))), st=OUT, sw=7)
	return s


def snapjaw_eye_red(d, e):
	x, y = SJ_EYE_R
	s = ''
	glow_r = {'normal': 62, 'happy': 72, 'shock': 56, 'angry': 90, 'sad': 40}[e]
	glow_a = {'normal': 0.75, 'happy': 0.8, 'shock': 0.6, 'angry': 0.95, 'sad': 0.35}[e]
	g = d.rad([(0, '#ff5a5a', glow_a), (0.45, '#ff2a2a', glow_a * 0.45), (1, '#ff0000', 0.0)], cx=x, cy=y, r=glow_r, user=True)
	s += C(x, y, glow_r, fill=g, st=None)
	s += C(x, y, 26, fill='#1a1a22', st=OUT, sw=5)
	s += C(x, y, 26, st='#9aa5b0', sw=3)
	red = SJ_RED if e != 'sad' else '#c21d1d'
	ir = {'normal': 15, 'happy': 17, 'shock': 9, 'angry': 18, 'sad': 13}[e]
	s += C(x, y, ir, fill=red, st=None)
	s += C(x, y, ir * 0.62, fill='#ff8a8a', st=None) + C(x, y, ir * 0.28, fill='#fff2f2', st=None)
	s += C(x - 8, y - 9, 4, fill=WHITE, st=None, op=0.85)
	if e != 'sad':
		# hard lens-flare streak across the red eye
		fl = 'M%s L%s L%s L%s Z' % (pt((x - 62, y)), pt((x, y - 2.6)), pt((x + 62, y)), pt((x, y + 2.6)))
		s += P(fl, fill='#ff6a6a', st=None, op=0.85) + P(fl, fill='#fff0f0', st=None, extra=' transform="translate(%s %s) scale(0.6 0.45) translate(%s %s)"' % (n(x), n(y), n(-x), n(-y)))
	if e == 'angry':
		for k in range(8):
			a = math.radians(k * 45 + 22)
			s += P('M%s L%s' % (pt((x + math.cos(a) * 30, y + math.sin(a) * 30)), pt((x + math.cos(a) * 46, y + math.sin(a) * 46))), st='#ff3030', sw=4, op=0.8)
	if e == 'happy':
		s += P(sparkle(x + 18, y - 18, 14), fill='#fff2f2', st=None, op=0.95)
	if e == 'shock':
		# glitch bars
		s += R(x - 40, y - 6, 34, 5, fill='#3ff0ff', st=None, op=0.7) + R(x + 8, y + 6, 40, 5, fill='#9b6bd6', st=None, op=0.85)
		s += R(x - 30, y + 16, 26, 4, fill=SJ_RED, st=None, op=0.8)
	return s


def snapjaw_brows(e):
	s = ''
	xl, yl = SJ_EYE_L
	xr, yr = SJ_EYE_R
	# green scaly ridge (left), metal plate (right)
	o, m, i = {'normal': (0, -2, 2), 'happy': (-6, -10, -6), 'shock': (-8, -14, -9), 'angry': (-6, 6, 18), 'sad': (8, 0, -12)}[e]
	base = yl - 36
	po, pm, pi = (xl - 24, base + o), (xl, base + m), (xl + 24, base + i)
	ridge = 'M%s Q%s %s' % (pt(po), pt((pm[0], pm[1] * 2 - (po[1] + pi[1]) / 2.0)), pt(pi))
	s += P(ridge, st=OUT, sw=15) + P(ridge, st=SJ_GD, sw=9)
	po, pm, pi = (xr + 26, base + o), (xr, base + m), (xr - 26, base + i)
	plate = poly([(po[0], po[1] - 6), (pi[0], pi[1] - 6), (pi[0], pi[1] + 6), (po[0], po[1] + 6)])
	s += P(plate, fill='#c4ccd5', st=OUT, sw=4)
	s += C((po[0] + pm[0]) / 2.0, (po[1] + pm[1]) / 2.0, 2.4, fill='#6f7b88', st=None) + C((pi[0] + pm[0]) / 2.0, (pi[1] + pm[1]) / 2.0, 2.4, fill='#6f7b88', st=None)
	return s


def snapjaw_hat(d, e):
	black = '#1f1a28'
	s = ''
	s += P('M150,96 Q240,80 330,96 Q340,106 320,112 Q240,98 160,112 Q140,106 150,96 Z', fill=black, st=OUT, sw=5)
	s += P('M196,98 L188,12 Q240,2 292,12 L284,98 Z', fill=black, st=OUT, sw=SW)
	s += P('M204,94 L198,20 Q208,17 216,16 L220,94 Z', fill=WHITE, st=None, op=0.12)
	s += E(240, 12, 52, 9, fill='#2e2838', st=OUT, sw=5)
	s += P('M192,70 L288,70 L286,96 L194,96 Z', fill='#c62828', st=OUT, sw=4.5)
	# aqua pool-light catching the shadow-side edge of the hat so it never melts into a dark background
	s += P('M285,18 L278,66', st=AQUA, sw=3.2, op=0.75) + P('M300,102 Q318,104 326,100', st=AQUA, sw=3, op=0.7)
	tf = hat_pose(e, 7, 240, 100, 0)
	return G(s, tf=tf)


def snapjaw_monocle(d, e):
	x, y = SJ_EYE_L
	s = C(x, y, 32, fill='#dff2ff', st=None, op=0.2)
	s += C(x, y, 32, st=OUT, sw=10) + C(x, y, 32, st='#f0c75a', sw=4.5)
	s += P('M%s Q%s %s' % (pt((x - 20, y - 14)), pt((x - 8, y - 28)), pt((x + 10, y - 27))), st=WHITE, sw=3, op=0.8)
	ch = 'M%s Q%s %s' % (pt((x - 26, y + 20)), pt((x - 62, y + 120)), pt((x - 30, y + 230)))
	chain = P(ch, st=OUT, sw=5.5) + P(ch, st='#f0c75a', sw=2.6, extra=' stroke-dasharray="4 3"')
	if e == 'shock':
		# monocle pops off!
		return G(chain + s, tf='translate(-34 34) ' + rot(-30, x, y)) + fx_shock_lines(x - 56, y - 30, -1)
	return chain + s


def snapjaw(e):
	d = Doc()
	c = dict(fur='#1d1a24', bw=1.06, arms=False, outfit=sj_outfit, hs=1.0)
	out = draw_body(d, c, e)
	out += sj_neck(d, c, e)
	jaw = {'normal': 0, 'happy': 50, 'shock': 32, 'angry': 14, 'sad': 6}[e]
	head = snapjaw_hat(d, e)
	chrome = sj_chrome(d)
	# ---- lower jaw (pale belly scales / chrome)
	lower_pts = [(382, 192), (388, 238), (368, 290), (334, 334), (292, 364 + jaw * 0.85), (240, 378 + jaw), (188, 364 + jaw * 0.85),
		(146, 334), (112, 290), (92, 238), (98, 192), (240, 240)]
	lj = smooth(lower_pts)
	kl = d.clip(lj)
	belly = P(lj, fill=SJ_BELLY, st=None)
	for yy in range(300, 460, 16):
		belly += P('M90,%d L240,%d' % (yy, yy + 6), st='#b5cc7a', sw=2.5, op=0.7)
	head += sj_split(d, lj, G(belly, clip=kl), P(lj, fill=sj_chrome_v(d), st=None))
	# hot-spring aqua under-light bouncing up onto the lower jaw from the pool
	ug = d.lin([(0, AQUA, 0.0), (0.55, AQUA, 0.0), (1, AQUA, 0.85)], user=(0, 250, 0, 372 + jaw))
	head += G(P(lj, st=ug, sw=20), clip=kl) + P(lj, st=OUT, sw=SIL)
	if jaw > 0:
		inner_pts = [(372, 214), (354, 258), (324, 300), (290, 330 + jaw * 0.72), (240, 346 + jaw * 0.95), (190, 330 + jaw * 0.72),
			(156, 300), (126, 258), (108, 214), (240, 226)]
		ip = smooth(inner_pts)
		ki = d.clip(ip)
		head += P(ip, fill='#7a1a24', st=None)
		head += G(E(240, 334 + jaw * 0.92, 64, 24 + jaw * 0.25, fill='#ff6f86', st=None) +
			P('M240,%s L240,%s' % (n(318 + jaw * 0.7), n(352 + jaw)), st='#d94a66', sw=3), clip=ki)
		head += P(ip, st=OUT, sw=4)
		low_line = [(352, 258), (324, 300), (290, 330 + jaw * 0.72), (240, 346 + jaw * 0.95), (190, 330 + jaw * 0.72), (156, 300), (128, 258)]
		head += sj_teeth(low_line, 15, outward=False, count=11)
	# ---- upper head
	up = smooth(SJ_MOUTH + SJ_TOP[1:])
	ku = d.clip(up)
	green = P(up, fill=SJ_G, st=None)
	green += P(up, fill=SJ_GD, st=None, op=0.55, extra=' transform="translate(6 10)"')
	green += P(up, fill=SJ_G, st=None, extra=' transform="translate(-2 -2)"')
	green += E(150, 120, 40, 22, fill=SJ_GL, st=None, op=0.5)
	green += sj_scales(d, ku, 96, 246, 150, 360, 22)
	for (x, y, r) in ((214, 168, 7), (220, 198, 7), (216, 228, 6.5), (222, 258, 6), (218, 286, 5.5)):
		green += E(x, y, r * 1.25, r, fill=SJ_GL, st=SJ_GD, sw=2.5)
	chromefill = P(up, fill=chrome, st=None)
	chromefill += P('M240,176 L380,182 M240,250 L360,256 M318,182 L318,252', st='#5d6875', sw=3, op=0.9)
	for (x, y) in ((256, 168), (290, 170), (340, 174), (370, 176), (258, 242), (300, 246), (344, 250), (318, 200), (318, 232), (270, 300), (296, 292)):
		chromefill += C(x, y, 4.4, fill='#9aa5b0', st='#4d5864', sw=2) + C(x - 1.3, y - 1.3, 1.5, fill=WHITE, st=None)
	for k in range(3):
		chromefill += R(330, 196 + k * 12, 38, 6.5, rx=3, fill='#3a434d', st=None)
	head += sj_split(d, up, G(green, clip=ku), G(chromefill, clip=ku))
	# ---- menacing lighting: brim shadow over the brow, red eye-light spilling over the chrome,
	# a hard red rim down the metal side, and sharp specular slashes on the chrome
	kr = d.clip('M240,-100 L600,-100 L600,700 L240,700 Z')
	ex, ey = SJ_EYE_R
	top_a = {'happy': 0.32, 'sad': 0.4}.get(e, 0.55)
	tg = d.lin([(0, '#120a24', top_a), (1, '#120a24', 0.0)], user=(0, 62, 0, 160))
	light = R(80, 50, 320, 120, fill=tg, st=None)
	spill_a = {'angry': 0.44, 'sad': 0.12}.get(e, 0.22)
	sg = d.rad([(0, '#e8300f', spill_a), (0.5, '#d0200a', spill_a * 0.4), (1, '#c01000', 0.0)], cx=ex, cy=ey, r=170, user=True)
	light += C(ex, ey, 170, fill=sg, st=None)
	rim_a = {'angry': 1.0, 'sad': 0.35}.get(e, 0.75)
	rg = d.rad([(0, '#ff4630', rim_a), (0.6, '#ff3a26', rim_a * 0.75), (1, '#ff3a26', 0.0)], cx=ex, cy=ey + 40, r=200, user=True)
	metal = P(up, st=rg, sw=22 if e == 'angry' else 17)
	for (a, b, w) in (((356, 262), (316, 330), 14), ((378, 262), (338, 330), 6), ((262, 84), (250, 104), 9)):
		metal += P(poly([(a[0], a[1]), (a[0] + w, a[1]), (b[0] + w, b[1]), (b[0], b[1])]), fill=WHITE, st=None, op=0.78)
	head += G(light + G(metal, clip=kr), clip=ku)
	# seam between flesh and metal
	zz = [(240, 112)]
	yy = 112
	k = 0
	while yy < 330:
		yy += 13
		k += 1
		zz.append((240 + (5 if k % 2 else -5), yy))
	head += P(line(zz), st='#2a2a30', sw=3.5)
	head += P(up, st=OUT, sw=SIL)
	# nostril knob at the snout tip
	knob = smooth([(240, 296), (266, 298), (280, 310), (270, 326), (240, 332), (210, 326), (200, 310), (214, 298)])
	head += sj_split(d, knob, P(knob, fill=SJ_GL, st=None), P(knob, fill='#d5dde4', st=None)) + P(knob, st=OUT, sw=4)
	head += E(224, 312, 7, 4.5, fill='#14301a', st=None, extra=' transform="%s"' % rot(-20, 224, 312))
	head += R(250, 307, 16, 3, rx=1.5, fill='#2a3038', st=None) + R(250, 313, 16, 3, rx=1.5, fill='#2a3038', st=None)
	# ---- teeth along the grin
	big = 19 if e != 'angry' else 15
	head += sj_teeth(SJ_MOUTH[1:-1], big, outward=True, count=13)
	if jaw == 0:
		head += sj_teeth(SJ_MOUTH[1:-1], 13, outward=False, offset=1, count=12)
	if e == 'sad':
		for side in (-1, 1):
			x0 = 240 + side * 138
			head += P('M%s Q%s %s' % (pt((x0, 206)), pt((x0 + side * 12, 214)), pt((x0 + side * 8, 236))), st=OUT, sw=5.5)
	# ---- eyes + brows
	head += snapjaw_eye_red(d, e)
	head += snapjaw_eye_green(d, e)
	head += snapjaw_brows(e)
	head += snapjaw_monocle(d, e)
	if e == 'sad':
		x, y = SJ_EYE_L
		head += P('M%s Q%s %s' % (pt((x - 6, y + 22)), pt((x - 12, y + 40)), pt((x - 10, y + 56))), st='#7cc8f5', sw=6, op=0.9)
		head += P(drop(x - 10, y + 66, 11), fill='#a6e0ff', st='#2f7fcf', sw=3) + E(x - 14, y + 64, 2.5, 4, fill=WHITE, st=None)
	if e == 'happy':
		for (x, y, a) in ((70, 120, 200), (64, 176, 180), (414, 110, -20), (420, 166, 0)):
			r = math.radians(a)
			head += P('M%s L%s' % (pt((x, y)), pt((x + math.cos(r) * 26, y + math.sin(r) * 26))), st=OUT, sw=5.5)
	elif e == 'shock':
		head += fx_sweat(396, 136, 14)
	elif e == 'angry':
		head += fx_anger(110, 96, 1.05)
		# the chrome half overheats: steam vents from the cheek grille
		for (x, y, r) in ((394, 214, 9), (412, 196, 12), (428, 172, 15), (438, 146, 10)):
			head += C(x, y, r, fill='#f4f6fa', st='#8a96a2', sw=3, op=0.95)
		for (x, y, r) in ((394, 214, 9), (412, 196, 12), (428, 172, 15), (438, 146, 10)):
			head += C(x, y, r - 2.5, fill='#f4f6fa', st=None, op=0.95)
		head += P('M372,206 L388,212 M374,220 L390,224', st='#ff5030', sw=3)
	tilt, bob = {'normal': (0, 0), 'happy': (-6, -4), 'shock': (0, -8), 'angry': (2, 4), 'sad': (4, 10)}[e]
	out += G(head, tf='translate(0 %s) rotate(%s 240 340)' % (n(bob), n(tilt)))
	return d.render(G(out, tf='translate(0 %s)' % n(SHIFT)))


# ============================================================================ main

CHARS = {
	'mochi': MOCHI, 'coco': COCO, 'wisp': WISP, 'bruno': BRUNO, 'lulu': LULU, 'pepper': PEPPER, 'duchess': DUCHESS,
	'bramble': BRAMBLE, 'nibs': NIBS, 'zuzu': ZUZU, 'reginald': REGINALD, 'grub': GRUB, 'tumble': TUMBLE,
	'marigold': MARIGOLD, 'fennel': FENNEL,
}

FORBIDDEN = re.compile(r'<\s*(text|filter|image|style|foreignObject|use|script|font)\b|xlink:href|href=|@import|url\((?!#)', re.I)


def portrait(cid, e):
	if cid == 'snapjaw':
		return snapjaw(e)
	return capybara(cid, CHARS[cid], e)


def check_file(path):
	src = open(path).read()
	errs = []
	if FORBIDDEN.search(src):
		errs.append('forbidden feature: ' + FORBIDDEN.search(src).group(0))
	if 'width="480" height="600" viewBox="0 0 480 600"' not in src:
		errs.append('bad size header')
	if len(src) > 60 * 1024:
		errs.append('too big: %d bytes' % len(src))
	if not src.rstrip().endswith('</svg>'):
		errs.append('truncated')
	return errs, len(src)


def main(argv):
	check_only = '--check' in argv
	ids = [a for a in argv if not a.startswith('--')] or IDS
	for cid in ids:
		if cid not in IDS:
			print('unknown id', cid)
			return 1
	os.makedirs(OUTDIR, exist_ok=True)
	bad = 0
	sizes = []
	for cid in ids:
		for e in EXPRS:
			path = os.path.join(OUTDIR, '%s_%s.svg' % (cid, e))
			if not check_only:
				with open(path, 'w') as fh:
					fh.write(portrait(cid, e))
			errs, size = check_file(path)
			sizes.append(size)
			if errs:
				bad += 1
				print('%s: %s' % (path, '; '.join(errs)))
	print('%s %d portraits (%d problems), %.1f KB avg, %.1f KB max' % (
		'checked' if check_only else 'wrote', len(sizes), bad, sum(sizes) / 1024.0 / max(len(sizes), 1), max(sizes) / 1024.0))
	return 1 if bad else 0


if __name__ == '__main__':
	sys.exit(main(sys.argv[1:]))
