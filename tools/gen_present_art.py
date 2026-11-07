#!/usr/bin/env python3
"""SPLASH TRIAL - presentation art generator (title logo bits, execution video props, game-over props).

Writes:
  art/props/title_*.svg   logo decorations for the title / credits screens
  art/props/exec_*.svg    execution video props (big top, magic boxes, saw, soda glass, ...)
                          and the game-over "Mochi's Last Soak" props (exec_soak_*)

Usage (from the project root):  python3 tools/gen_present_art.py
Only SVG 1.1 basics are used (no text / filters / images / CSS) so Godot's ThorVG rasterizes it.
"""
import math
import os
import random

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "art", "props")
OL = "#2a1a10"      # outline used by the character art
INK = "#120a24"     # logo outline (matches Style.BG_DARK)


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
	fo = ""
	if fx is not None:
		fo = ' fx="%s" fy="%s"' % (f(fx), f(fy))
	return '<radialGradient id="%s" cx="%s" cy="%s" r="%s"%s%s>%s</radialGradient>' % (
		gid, f(cx), f(cy), f(r), fo, u, stops(seq))


def star_pts(cx, cy, ro, ri, n=5, rot=-90.0):
	p = []
	for i in range(n * 2):
		r = ro if i % 2 == 0 else ri
		a = math.radians(rot + i * 180.0 / n)
		p.append((cx + r * math.cos(a), cy + r * math.sin(a)))
	return pts(p)


def star(cx, cy, ro, ri, fill, stroke=None, sw=0, n=5, rot=-90.0, op=1.0):
	s = ' stroke="%s" stroke-width="%s" stroke-linejoin="round"' % (stroke, f(sw)) if stroke else ""
	o = ' opacity="%s"' % f(op) if op < 1.0 else ""
	return '<polygon points="%s" fill="%s"%s%s/>' % (star_pts(cx, cy, ro, ri, n, rot), fill, s, o)


def sparkle(cx, cy, r, fill="#ffffff", op=1.0):
	k = r * 0.22
	p = [(cx, cy - r), (cx + k, cy - k), (cx + r, cy), (cx + k, cy + k), (cx, cy + r), (cx - k, cy + k), (cx - r, cy), (cx - k, cy - k)]
	o = ' opacity="%s"' % f(op) if op < 1.0 else ""
	return '<polygon points="%s" fill="%s"%s/>' % (pts(p), fill, o)


def write(name, content):
	path = os.path.join(OUT, name + ".svg")
	with open(path, "w", encoding="utf-8") as fh:
		fh.write(content)
	return path


# ================================================================== TITLE
def title_drop():
	w, h = 240, 300
	drop = "M120,10 C150,74 226,140 226,196 A106,106 0 0 1 14,196 C14,140 90,74 120,10 Z"
	defs = (rad("dg", 0.38, 0.38, 0.75, [(0, "#b8fff4"), (0.45, "#3ee0d0"), (0.85, "#1a8f9e"), (1, "#0f5d6e")])
		+ lin("wv", 0, 0, 0, 1, [(0, "#1a8f9e"), (1, "#0b4a5c")])
		+ '<clipPath id="dc"><path d="%s"/></clipPath>' % drop)
	b = []
	b.append('<path d="%s" fill="%s" transform="translate(6,8)" opacity="0.35"/>' % (drop, INK))
	b.append('<path d="%s" fill="url(#dg)"/>' % drop)
	# wave band inside the drop
	b.append('<g clip-path="url(#dc)">')
	b.append('<path d="M0,196 C30,176 60,176 90,196 C120,216 150,216 180,196 C210,176 230,180 240,186 L240,300 L0,300 Z" fill="url(#wv)"/>')
	b.append('<path d="M0,196 C30,176 60,176 90,196 C120,216 150,216 180,196 C210,176 230,180 240,186" fill="none" stroke="#e8fffb" stroke-width="7" stroke-linecap="round"/>')
	# yuzu slice bobbing on the wave
	cx, cy, r = 120, 222, 46
	b.append('<circle cx="%d" cy="%d" r="%d" fill="#ff9a1f" stroke="%s" stroke-width="6"/>' % (cx, cy, r, INK))
	b.append('<circle cx="%d" cy="%d" r="%d" fill="#fff3b0"/>' % (cx, cy, r - 9))
	for i in range(8):
		a = math.radians(i * 45 + 22.5)
		a1 = math.radians(i * 45 + 22.5 + 45)
		p = [(cx, cy), (cx + (r - 13) * math.cos(a) * 0.92, cy + (r - 13) * math.sin(a) * 0.92),
			(cx + (r - 13) * math.cos(a1) * 0.92, cy + (r - 13) * math.sin(a1) * 0.92)]
		b.append('<polygon points="%s" fill="#ffd166" stroke="#fff3b0" stroke-width="4" stroke-linejoin="round"/>' % pts(p))
	b.append('<circle cx="%d" cy="%d" r="6" fill="#fff8d8"/>' % (cx, cy))
	b.append('</g>')
	# gloss
	b.append('<path d="M70,120 C80,96 96,76 108,58" fill="none" stroke="#ffffff" stroke-width="12" stroke-linecap="round" opacity="0.85"/>')
	b.append('<circle cx="62" cy="146" r="7" fill="#ffffff" opacity="0.85"/>')
	b.append('<path d="%s" fill="none" stroke="%s" stroke-width="9" stroke-linejoin="round"/>' % (drop, INK))
	b.append(sparkle(204, 52, 18, "#fff6c8"))
	b.append(sparkle(30, 60, 11, "#ffffff", 0.9))
	return svg(w, h, "\n".join(b), defs)


def title_yuzu():
	w, h = 120, 120
	defs = rad("yg", 0.36, 0.34, 0.75, [(0, "#fff0a0"), (0.45, "#ffc23d"), (1, "#f08a10")])
	b = []
	b.append('<ellipse cx="62" cy="72" rx="46" ry="42" fill="%s" opacity="0.3"/>' % OL)
	b.append('<path d="M60,26 C92,24 106,46 104,70 C102,96 82,110 60,110 C34,110 14,94 14,68 C14,44 32,28 60,26 Z" fill="url(#yg)" stroke="%s" stroke-width="5" stroke-linejoin="round"/>' % OL)
	rnd = random.Random(7)
	for _ in range(14):
		x = rnd.uniform(28, 92)
		y = rnd.uniform(44, 98)
		b.append('<circle cx="%s" cy="%s" r="1.8" fill="#e07a08" opacity="0.6"/>' % (f(x), f(y)))
	b.append('<ellipse cx="42" cy="52" rx="12" ry="8" fill="#ffffff" opacity="0.7" transform="rotate(-30 42 52)"/>')
	b.append('<path d="M60,28 L62,14" stroke="%s" stroke-width="5" stroke-linecap="round"/>' % OL)
	b.append('<path d="M62,18 C70,4 92,2 100,10 C92,24 74,26 62,18 Z" fill="#6cc04a" stroke="%s" stroke-width="4.5" stroke-linejoin="round"/>' % OL)
	b.append('<path d="M66,17 C76,12 86,10 94,11" fill="none" stroke="#2f7a2a" stroke-width="2.5" stroke-linecap="round"/>')
	return svg(w, h, "\n".join(b), defs)


def title_wave():
	w, h = 900, 100
	defs = lin("wg", 0, 0, 0, 1, [(0, "#7ff3e6"), (0.5, "#3ee0d0"), (1, "#1a8f9e")])
	# a row of curling crests
	n = 9
	seg = w / n
	d = "M0,100 L0,62 "
	for i in range(n):
		x0 = i * seg
		d += "C%s,%s %s,%s %s,%s " % (f(x0 + seg * 0.25), "30", f(x0 + seg * 0.55), "18", f(x0 + seg * 0.72), "40")
		d += "C%s,%s %s,%s %s,%s " % (f(x0 + seg * 0.62), "48", f(x0 + seg * 0.58), "34", f(x0 + seg * 0.66), "32")
		d += "C%s,%s %s,%s %s,%s " % (f(x0 + seg * 0.82), "36", f(x0 + seg * 0.9), "60", f(x0 + seg), "62")
	d += "L900,100 Z"
	b = []
	b.append('<path d="%s" fill="url(#wg)" stroke="%s" stroke-width="6" stroke-linejoin="round"/>' % (d, INK))
	for i in range(n):
		x0 = i * seg
		b.append('<path d="M%s,48 C%s,32 %s,26 %s,30" fill="none" stroke="#ffffff" stroke-width="5" stroke-linecap="round" opacity="0.9"/>' % (
			f(x0 + seg * 0.18), f(x0 + seg * 0.3), f(x0 + seg * 0.45), f(x0 + seg * 0.56)))
		b.append('<circle cx="%s" cy="76" r="4" fill="#e8fffb" opacity="0.7"/>' % f(x0 + seg * 0.4))
		b.append('<circle cx="%s" cy="86" r="2.5" fill="#e8fffb" opacity="0.6"/>' % f(x0 + seg * 0.7))
	return svg(w, h, "\n".join(b), defs)


def title_sparkle():
	w, h = 64, 64
	defs = rad("sg", 0.5, 0.5, 0.5, [(0, "#ffffff"), (0.4, "#fff3c0"), (1, "#ffd166")])
	b = [sparkle(32, 32, 30, "url(#sg)"), '<circle cx="32" cy="32" r="5" fill="#ffffff"/>']
	return svg(w, h, "\n".join(b), defs)


# ================================================================== EXECUTION
def exec_tent():
	W, H = 1280, 720
	defs = (rad("bg", 640, 330, 820, [(0, "#5a1f44"), (0.6, "#2a0f2e"), (1, "#14081c")], user=True)
		+ lin("shade", 0, 0, 0, 1, [(0, "#0c0418", 0.9), (0.6, "#0c0418", 0.4), (1, "#0c0418", 0.1)])
		+ lin("wall", 0, 440, 0, 560, [(0, "#2c1446"), (1, "#3d1d5c")], user=True)
		+ lin("fold", 0, 0, 1, 0, [(0, "#000000", 0.35), (0.5, "#ffffff", 0.06), (1, "#000000", 0.35)])
		+ lin("floor", 0, 540, 0, 720, [(0, "#6b4126"), (1, "#a06a3c")], user=True)
		+ lin("velv", 0, 0, 1, 0, [(0, "#5e0f1c"), (0.35, "#b82a3a"), (0.6, "#8a1a2a"), (1, "#4a0a14")])
		+ rad("glow", 0.5, 0.5, 0.5, [(0, "#ffe9a0", 0.8), (1, "#ffe9a0", 0)]))
	b = ['<rect width="%d" height="%d" fill="url(#bg)"/>' % (W, H)]
	# tent canvas stripes fanning from the apex
	ax, ay = 640, -160
	n = 18
	x0, x1 = -520, 1800
	sw = (x1 - x0) / n
	for i in range(n):
		xa = x0 + i * sw
		col = "#a02a3a" if i % 2 == 0 else "#dcc8a0"
		b.append('<polygon points="%s" fill="%s"/>' % (pts([(ax, ay), (xa, 432), (xa + sw, 432)]), col))
	# seams
	for i in range(n + 1):
		xa = x0 + i * sw
		b.append('<line x1="%d" y1="%d" x2="%s" y2="432" stroke="#5a1424" stroke-width="3" opacity="0.5"/>' % (ax, ay, f(xa)))
	b.append('<rect x="0" y="0" width="%d" height="432" fill="url(#shade)"/>' % W)
	# back wall curtain (dark violet folds)
	b.append('<rect x="0" y="428" width="%d" height="140" fill="url(#wall)"/>' % W)
	for i in range(32):
		b.append('<rect x="%d" y="428" width="40" height="140" fill="url(#fold)"/>' % (i * 40))
	# valance with scallops
	b.append('<rect x="0" y="412" width="%d" height="30" fill="#d8a93a" stroke="%s" stroke-width="4"/>' % (W, OL))
	for i in range(21):
		cx = i * 64 + 32
		col = "#b8323f" if i % 2 == 0 else "#7a1a4a"
		b.append('<path d="M%d,440 A32,30 0 0 0 %d,440 Z" fill="%s" stroke="%s" stroke-width="4" stroke-linejoin="round"/>' % (cx - 32, cx + 32, col, OL))
		b.append('<circle cx="%d" cy="472" r="5" fill="#ffd166" stroke="%s" stroke-width="2"/>' % (cx, OL))
	# marquee bulbs on the valance
	for i in range(40):
		cx = i * 32 + 16
		b.append('<circle cx="%d" cy="427" r="12" fill="url(#glow)"/>' % cx)
		b.append('<circle cx="%d" cy="427" r="4.5" fill="#fff6c8"/>' % cx)
	# bunting garlands
	cols = ["#ffb347", "#3ee0d0", "#9b6bd6", "#ff4f6d", "#ffd166"]
	for g, (ya, sag) in enumerate([(70, 90), (150, 70)]):
		b.append('<path d="M-20,%d Q640,%d 1300,%d" fill="none" stroke="#2a1a10" stroke-width="3"/>' % (ya, ya + sag * 2, ya))
		for i in range(26):
			t = (i + 0.5) / 26.0
			x = -20 + 1320 * t
			y = (1 - t) * (1 - t) * ya + 2 * (1 - t) * t * (ya + sag * 2) + t * t * ya
			col = cols[(i + g * 2) % len(cols)]
			b.append('<polygon points="%s" fill="%s" stroke="%s" stroke-width="2.5" stroke-linejoin="round"/>' % (
				pts([(x - 18, y), (x + 18, y), (x, y + 34)]), col, OL))
	# side curtains (tied back)
	for side in (0, 1):
		if side == 0:
			d = "M0,0 L230,0 C200,180 120,330 92,412 C120,470 170,600 190,720 L0,720 Z"
			tie = (98, 412)
		else:
			d = "M1280,0 L1050,0 C1080,180 1160,330 1188,412 C1160,470 1110,600 1090,720 L1280,720 Z"
			tie = (1182, 412)
		b.append('<path d="%s" fill="url(#velv)" stroke="%s" stroke-width="5" stroke-linejoin="round"/>' % (d, OL))
		for k in range(4):
			if side == 0:
				x = 30 + k * 40
				b.append('<path d="M%d,0 C%d,170 %d,330 %d,410" fill="none" stroke="#4a0a14" stroke-width="4" opacity="0.6"/>' % (x, x - 6, x - 30 - k * 8, tie[0] - 20 + k * 4))
			else:
				x = 1250 - k * 40
				b.append('<path d="M%d,0 C%d,170 %d,330 %d,410" fill="none" stroke="#4a0a14" stroke-width="4" opacity="0.6"/>' % (x, x + 6, x + 30 + k * 8, tie[0] + 20 - k * 4))
		b.append('<ellipse cx="%d" cy="%d" rx="34" ry="14" fill="#ffd166" stroke="%s" stroke-width="4"/>' % (tie[0], tie[1], OL))
		b.append('<circle cx="%d" cy="%d" r="9" fill="#d8a93a" stroke="%s" stroke-width="3"/>' % (tie[0] + (14 if side == 0 else -14), tie[1] + 22, OL))
	# stage floor (perspective planks)
	b.append('<polygon points="%s" fill="url(#floor)" stroke="%s" stroke-width="4"/>' % (pts([(120, 552), (1160, 552), (1400, 720), (-120, 720)]), OL))
	for i in range(1, 18):
		t = i / 18.0
		xt = 120 + 1040 * t
		xb = -120 + 1520 * t
		b.append('<line x1="%s" y1="552" x2="%s" y2="720" stroke="#4a2a14" stroke-width="2.5" opacity="0.55"/>' % (f(xt), f(xb)))
	for y in (590, 640, 700):
		b.append('<line x1="0" y1="%d" x2="1280" y2="%d" stroke="#4a2a14" stroke-width="2" opacity="0.35"/>' % (y, y))
	b.append('<ellipse cx="640" cy="610" rx="420" ry="50" fill="#ffe9a0" opacity="0.12"/>')
	return svg(W, H, "\n".join(b), defs)


def exec_footlights():
	w, h = 1280, 120
	defs = (lin("lip", 0, 0, 0, 1, [(0, "#7a1a2a"), (1, "#3a0812")])
		+ rad("fl", 0.5, 0.8, 0.6, [(0, "#fff3c0", 0.85), (1, "#fff3c0", 0)]))
	b = []
	b.append('<rect x="0" y="22" width="%d" height="98" fill="url(#lip)"/>' % w)
	b.append('<rect x="0" y="18" width="%d" height="12" fill="#d8a93a" stroke="%s" stroke-width="4"/>' % (w, OL))
	for i in range(14):
		cx = 46 + i * 92
		b.append(star(cx, 74, 15, 6.5, "#ffd166", OL, 3))
	for i in range(13):
		cx = 92 + i * 92
		b.append('<ellipse cx="%d" cy="8" rx="44" ry="26" fill="url(#fl)"/>' % cx)
		b.append('<path d="M%d,24 A22,18 0 0 1 %d,24 Z" fill="#2a2030" stroke="%s" stroke-width="4" stroke-linejoin="round"/>' % (cx - 22, cx + 22, OL))
		b.append('<ellipse cx="%d" cy="20" rx="12" ry="6" fill="#fff6c8"/>' % cx)
	return svg(w, h, "\n".join(b), defs)


def exec_curtain(side):
	w, h = 680, 720
	defs = lin("cv", 0, 0, 1, 0, [(0, "#6a1020"), (0.5, "#c0303f"), (1, "#6a1020")])
	b = []
	nf = 8
	fw = w / nf
	for i in range(nf):
		x = i * fw
		b.append('<rect x="%s" y="0" width="%s" height="%d" fill="url(#cv)"/>' % (f(x), f(fw + 1), h))
	# bottom fringe
	b.append('<rect x="0" y="676" width="%d" height="20" fill="#d8a93a" stroke="%s" stroke-width="4"/>' % (w, OL))
	for i in range(0, w, 14):
		b.append('<rect x="%d" y="694" width="8" height="26" fill="#ffd166" stroke="%s" stroke-width="2"/>' % (i + 3, OL))
	# swag at the top
	b.append('<path d="M0,0 L%d,0 L%d,60 C%d,110 %d,110 0,70 Z" fill="#8a1a2a" stroke="%s" stroke-width="4" stroke-linejoin="round"/>' % (w, w, w * 0.6, w * 0.3, OL))
	edge_x = w if side == "l" else 0
	b.append('<line x1="%d" y1="0" x2="%d" y2="%d" stroke="%s" stroke-width="6"/>' % (edge_x, edge_x, h, OL))
	b.append(star(w - 90 if side == "l" else 90, 360, 34, 14, "#ffd166", OL, 4))
	return svg(w, h, "\n".join(b), defs)


def exec_spot():
	w, h = 520, 760
	defs = (lin("cone", 0, 0, 0, 1, [(0, "#fff6d0", 0.75), (0.7, "#fff0c0", 0.28), (1, "#fff0c0", 0.18)])
		+ rad("pool", 0.5, 0.5, 0.5, [(0, "#fff6d0", 0.7), (1, "#fff6d0", 0)]))
	b = ['<polygon points="%s" fill="url(#cone)"/>' % pts([(236, 0), (284, 0), (500, 700), (20, 700)]),
		'<polygon points="%s" fill="#ffffff" opacity="0.14"/>' % pts([(250, 0), (270, 0), (360, 700), (160, 700)]),
		'<ellipse cx="260" cy="700" rx="260" ry="60" fill="url(#pool)"/>']
	return svg(w, h, "\n".join(b), defs)


BOX_SCHEMES = {
	"a": ("#8452d8", "#4b2290", "#e8e6ff", "#ffd166"),
	"b": ("#e2475a", "#8f1d33", "#ffd166", "#e8e6ff"),
	"c": ("#2cc4b4", "#0f6f6e", "#ffb347", "#ffd166"),
}


def exec_box_half(scheme, side):
	"""Half of a horizontal magician's box. Full box = 360x180, each half 180 wide (+pad)."""
	top, bot, starc, trim = BOX_SCHEMES[scheme]
	pad = 6
	w, h = 180 + pad * 2, 180 + pad * 2
	defs = lin("bx", 0, 0, 0, 1, [(0, top), (1, bot)])
	b = []
	x0, y0, x1, y1 = pad, pad, pad + 180, pad + 180
	# outer body (rounded on the outer end only)
	if side == "l":
		d = "M%d,%d L%d,%d L%d,%d L%d,%d Q%d,%d %d,%d L%d,%d Q%d,%d %d,%d Z" % (
			x1, y0, x1, y1, x0 + 14, y1, x0 + 14, y1, x0, y1, x0, y1 - 14, x0, y0 + 14, x0, y0, x0 + 14, y0)
	else:
		d = "M%d,%d L%d,%d L%d,%d Q%d,%d %d,%d L%d,%d Q%d,%d %d,%d Z" % (
			x0, y0, x1 - 14, y0, x1 - 14, y0, x1, y0, x1, y0 + 14, x1, y1 - 14, x1, y1, x1 - 14, y1)
		d = "M%d,%d L%d,%d Q%d,%d %d,%d L%d,%d Q%d,%d %d,%d L%d,%d Z" % (
			x0, y0, x1 - 14, y0, x1, y0, x1, y0 + 14, x1, y1 - 14, x1, y1, x1 - 14, y1, x0, y1)
	b.append('<path d="%s" fill="url(#bx)" stroke="%s" stroke-width="5" stroke-linejoin="round"/>' % (d, OL))
	# lid strip
	b.append('<rect x="%d" y="%d" width="180" height="22" fill="%s" opacity="0.35"/>' % (x0, y0, "#000000"))
	b.append('<line x1="%d" y1="%d" x2="%d" y2="%d" stroke="%s" stroke-width="4"/>' % (x0, y0 + 22, x1, y0 + 22, OL))
	# trim frame
	ix0 = x0 + (16 if side == "l" else 8)
	ix1 = x1 - (8 if side == "l" else 16)
	b.append('<rect x="%d" y="%d" width="%d" height="%d" rx="8" fill="none" stroke="%s" stroke-width="5"/>' % (
		ix0, y0 + 34, ix1 - ix0, 180 - 50, trim))
	rnd = random.Random(hash(scheme + side) & 0xffff)
	spots = [(0.3, 0.42), (0.7, 0.58), (0.42, 0.78), (0.78, 0.34), (0.2, 0.7)]
	for (sx, sy) in spots:
		cx = ix0 + (ix1 - ix0) * sx + rnd.uniform(-6, 6)
		cy = y0 + 180 * sy
		b.append(star(cx, cy, 13, 5.5, starc, OL, 2.5))
	b.append(sparkle(ix0 + (ix1 - ix0) * 0.55, y0 + 180 * 0.48, 7, "#ffffff", 0.9))
	# the cut edge: dashed "cut here" line
	cx = x1 - 3 if side == "l" else x0 + 3
	for k in range(9):
		yy = y0 + 6 + k * 20
		b.append('<line x1="%d" y1="%d" x2="%d" y2="%d" stroke="#ffffff" stroke-width="4" stroke-linecap="round" opacity="0.85"/>' % (cx, yy, cx, yy + 9))
	if side == "r":
		# foot holes on the right end
		b.append('<ellipse cx="%d" cy="%d" rx="7" ry="20" fill="#1a0a20" stroke="%s" stroke-width="3"/>' % (x1 - 6, y0 + 92, OL))
		b.append('<ellipse cx="%d" cy="%d" rx="7" ry="20" fill="#1a0a20" stroke="%s" stroke-width="3"/>' % (x1 - 6, y0 + 140, OL))
	else:
		# neck opening on the top-left
		b.append('<ellipse cx="%d" cy="%d" rx="58" ry="9" fill="#1a0a20" stroke="%s" stroke-width="3"/>' % (x0 + 92, y0 + 4, OL))
	return svg(w, h, "\n".join(b), defs)


def exec_stand():
	w, h = 420, 210
	defs = lin("gd", 0, 0, 0, 1, [(0, "#ffe08a"), (1, "#b8862a")])
	b = []
	b.append('<rect x="10" y="4" width="400" height="26" rx="8" fill="url(#gd)" stroke="%s" stroke-width="5"/>' % OL)
	for x in (60, 360):
		b.append('<path d="M%d,30 L%d,200 L%d,200 L%d,30 Z" fill="#6a3cc0" stroke="%s" stroke-width="5" stroke-linejoin="round"/>' % (x - 16, x - 10, x + 10, x + 16, OL))
		b.append('<circle cx="%d" cy="110" r="12" fill="url(#gd)" stroke="%s" stroke-width="4"/>' % (x, OL))
	b.append('<rect x="70" y="140" width="280" height="14" rx="6" fill="url(#gd)" stroke="%s" stroke-width="4"/>' % OL)
	b.append('<path d="M140,30 Q210,80 280,30" fill="#c0303f" stroke="%s" stroke-width="4"/>' % OL)
	b.append('<circle cx="210" cy="56" r="7" fill="#ffd166" stroke="%s" stroke-width="3"/>' % OL)
	return svg(w, h, "\n".join(b), defs)


def exec_saw():
	w, h = 580, 150
	defs = (lin("bl", 0, 0, 0, 1, [(0, "#ffffff"), (0.4, "#d8dde8"), (1, "#8f98aa")])
		+ lin("wd", 0, 0, 0, 1, [(0, "#e09a50"), (1, "#8a4a1c")]))
	b = []
	teeth = []
	x = 14
	while x < 440:
		teeth.append((x, 96))
		teeth.append((x + 8, 112))
		x += 16
	poly = [(10, 46), (440, 30)] + [(440, 96)] + list(reversed(teeth))
	b.append('<polygon points="%s" fill="url(#bl)" stroke="%s" stroke-width="5" stroke-linejoin="round"/>' % (pts(poly), OL))
	b.append('<line x1="30" y1="60" x2="420" y2="46" stroke="#ffffff" stroke-width="5" stroke-linecap="round" opacity="0.8"/>')
	b.append('<circle cx="60" cy="70" r="6" fill="#8f98aa" stroke="%s" stroke-width="2.5"/>' % OL)
	# handle
	b.append('<path d="M430,20 C470,6 540,8 566,30 C580,60 576,110 556,134 C520,146 470,140 436,120 Z" fill="url(#wd)" stroke="%s" stroke-width="5" stroke-linejoin="round"/>' % OL)
	b.append('<path d="M470,48 C500,40 530,44 540,60 C546,80 540,98 526,104 C500,108 478,100 468,86 Z" fill="#2a0f2e" stroke="%s" stroke-width="4" stroke-linejoin="round"/>' % OL)
	for yy in (36, 116):
		b.append('<circle cx="446" cy="%d" r="6" fill="#ffd166" stroke="%s" stroke-width="2.5"/>' % (yy, OL))
	return svg(w, h, "\n".join(b), defs)


def exec_feet():
	w, h = 130, 120
	b = []
	for cy in (34, 84):
		b.append('<path d="M0,%d L58,%d C78,%d 96,%d 104,%d C120,%d 124,%d 116,%d C120,%d 114,%d 100,%d C86,%d 70,%d 58,%d L0,%d Z" fill="#5a3a28" stroke="%s" stroke-width="5" stroke-linejoin="round"/>' % (
			cy - 16, cy - 18, cy - 22, cy - 22, cy - 18, cy - 14, cy - 4, cy + 2, cy + 10, cy + 20, cy + 20, cy + 22, cy + 22, cy + 18, cy + 16, OL))
		b.append('<ellipse cx="94" cy="%d" rx="12" ry="14" fill="#d8a888"/>' % cy)
		for k, dy in enumerate((-12, 0, 12)):
			b.append('<circle cx="%d" cy="%d" r="5.5" fill="#d8a888" stroke="%s" stroke-width="2.5"/>' % (112 if k == 1 else 109, cy + dy, OL))
		b.append('<rect x="0" y="%d" width="40" height="%d" fill="#ffffff" stroke="%s" stroke-width="4"/>' % (cy - 19, 38, OL))
		b.append('<line x1="20" y1="%d" x2="20" y2="%d" stroke="#9b6bd6" stroke-width="6"/>' % (cy - 17, cy + 17))
	return svg(w, h, "\n".join(b))


def exec_lever():
	w, h = 140, 240
	defs = lin("lb", 0, 0, 0, 1, [(0, "#e2475a"), (1, "#8f1d33")])
	b = []
	# stick (pivot at 70,170) pointing up-left
	b.append('<line x1="70" y1="170" x2="40" y2="36" stroke="%s" stroke-width="16" stroke-linecap="round"/>' % OL)
	b.append('<line x1="70" y1="170" x2="40" y2="36" stroke="#c8ccd8" stroke-width="8" stroke-linecap="round"/>')
	b.append('<circle cx="40" cy="30" r="24" fill="#ff4f6d" stroke="%s" stroke-width="5"/>' % OL)
	b.append('<circle cx="32" cy="22" r="7" fill="#ffffff" opacity="0.8"/>')
	# base
	b.append('<rect x="14" y="160" width="112" height="76" rx="10" fill="url(#lb)" stroke="%s" stroke-width="5"/>' % OL)
	b.append('<rect x="28" y="176" width="84" height="12" rx="6" fill="#1a0a20" stroke="%s" stroke-width="3"/>' % OL)
	b.append(star(70, 212, 14, 6, "#ffd166", OL, 3))
	return svg(w, h, "\n".join(b), defs)


def exec_trapdoor():
	w, h = 280, 70
	defs = lin("tw", 0, 0, 0, 1, [(0, "#8a5a34"), (1, "#5a3820")])
	b = []
	poly = [(40, 6), (240, 6), (274, 64), (6, 64)]
	b.append('<polygon points="%s" fill="url(#tw)" stroke="%s" stroke-width="5" stroke-linejoin="round"/>' % (pts(poly), OL))
	for t in (0.25, 0.5, 0.75):
		xt = 40 + 200 * t
		xb = 6 + 268 * t
		b.append('<line x1="%s" y1="8" x2="%s" y2="62" stroke="#3a2010" stroke-width="3"/>' % (f(xt), f(xb)))
	b.append('<path d="M90,18 L190,52 M190,18 L90,52" stroke="#ff4f6d" stroke-width="8" stroke-linecap="round" opacity="0.85"/>')
	for x in (70, 210):
		b.append('<rect x="%d" y="2" width="22" height="10" rx="3" fill="#8f98aa" stroke="%s" stroke-width="3"/>' % (x - 11, OL))
	return svg(w, h, "\n".join(b), defs)


def exec_hole():
	w, h = 280, 70
	defs = lin("hg", 0, 0, 0, 1, [(0, "#000000"), (1, "#1a0a20")])
	poly = [(40, 6), (240, 6), (274, 64), (6, 64)]
	b = ['<polygon points="%s" fill="url(#hg)" stroke="%s" stroke-width="5" stroke-linejoin="round"/>' % (pts(poly), OL),
		'<polygon points="%s" fill="#3a1a4a" opacity="0.6"/>' % pts([(40, 6), (240, 6), (230, 20), (50, 20)])]
	return svg(w, h, "\n".join(b), defs)


GLASS = ("M170,6 L270,6 L270,120 C270,170 432,200 432,300 L432,560 C432,586 414,600 388,600 "
	"L52,600 C26,600 8,586 8,560 L8,300 C8,200 170,170 170,120 Z")


def exec_glass_back():
	w, h = 440, 610
	defs = (lin("soda", 0, 0, 0, 1, [(0, "#ffe27a", 0.95), (0.5, "#ffc23d", 0.95), (1, "#f59020", 0.97)])
		+ '<clipPath id="gc"><path d="%s"/></clipPath>' % GLASS)
	b = ['<path d="%s" fill="#cfefff" opacity="0.2"/>' % GLASS, '<g clip-path="url(#gc)">',
		'<rect x="0" y="236" width="440" height="380" fill="url(#soda)"/>',
		'<rect x="0" y="226" width="440" height="22" fill="#fff8e0" opacity="0.95"/>']
	rnd = random.Random(3)
	for _ in range(26):
		b.append('<circle cx="%s" cy="%s" r="%s" fill="#fff8e0"/>' % (f(rnd.uniform(10, 430)), f(rnd.uniform(222, 248)), f(rnd.uniform(6, 14))))
	b.append('</g>')
	b.append('<path d="%s" fill="none" stroke="%s" stroke-width="4" opacity="0.4"/>' % (GLASS, OL))
	return svg(w, h, "\n".join(b), defs)


def exec_glass_front():
	w, h = 440, 610
	defs = (lin("tint", 0, 0, 0, 1, [(0, "#ffd060", 0.38), (1, "#ff9a20", 0.62)])
		+ '<clipPath id="gc"><path d="%s"/></clipPath>' % GLASS)
	b = ['<g clip-path="url(#gc)">',
		'<rect x="0" y="244" width="440" height="380" fill="url(#tint)"/>',
		'<path d="M0,246 C80,232 160,258 240,244 C320,230 380,256 440,242" fill="none" stroke="#fff8e0" stroke-width="7" opacity="0.9"/>']
	rnd = random.Random(11)
	for _ in range(14):
		x = rnd.uniform(20, 420)
		y = rnd.uniform(280, 580)
		r = rnd.uniform(4, 11)
		b.append('<circle cx="%s" cy="%s" r="%s" fill="none" stroke="#fffbe8" stroke-width="2.5" opacity="0.85"/>' % (f(x), f(y), f(r)))
	b.append('</g>')
	# glass shine
	b.append('<path d="M40,300 C40,250 70,222 120,200" fill="none" stroke="#ffffff" stroke-width="14" stroke-linecap="round" opacity="0.55"/>')
	b.append('<path d="M34,340 L34,540" stroke="#ffffff" stroke-width="12" stroke-linecap="round" opacity="0.45"/>')
	b.append('<path d="M396,320 L396,520" stroke="#ffffff" stroke-width="6" stroke-linecap="round" opacity="0.35"/>')
	b.append('<path d="M190,16 L190,110" stroke="#ffffff" stroke-width="8" stroke-linecap="round" opacity="0.5"/>')
	b.append('<path d="%s" fill="none" stroke="%s" stroke-width="7" stroke-linejoin="round"/>' % (GLASS, OL))
	# lip ring of the neck
	b.append('<rect x="160" y="2" width="120" height="18" rx="8" fill="#e8f8ff" stroke="%s" stroke-width="5" opacity="0.95"/>' % OL)
	# yuzu wheel stuck on the shoulder
	cx, cy, r = 352, 238, 40
	b.append('<circle cx="%d" cy="%d" r="%d" fill="#ff9a1f" stroke="%s" stroke-width="5"/>' % (cx, cy, r, OL))
	b.append('<circle cx="%d" cy="%d" r="%d" fill="#fff3b0"/>' % (cx, cy, r - 8))
	for i in range(8):
		a = math.radians(i * 45 + 22.5)
		a1 = math.radians(i * 45 + 67.5)
		p = [(cx, cy), (cx + (r - 12) * math.cos(a), cy + (r - 12) * math.sin(a)), (cx + (r - 12) * math.cos(a1), cy + (r - 12) * math.sin(a1))]
		b.append('<polygon points="%s" fill="#ffd166" stroke="#fff3b0" stroke-width="3.5" stroke-linejoin="round"/>' % pts(p))
	return svg(w, h, "\n".join(b), defs)


def exec_cork():
	w, h = 140, 120
	defs = lin("ck", 0, 0, 1, 0, [(0, "#a8703c"), (0.45, "#e0aa6a"), (1, "#9a6232")])
	b = ['<path d="M10,22 C10,8 22,4 70,4 C118,4 130,8 130,22 L112,112 C110,118 30,118 28,112 Z" fill="url(#ck)" stroke="%s" stroke-width="5" stroke-linejoin="round"/>' % OL,
		'<ellipse cx="70" cy="16" rx="56" ry="10" fill="#f0c48a" stroke="%s" stroke-width="3"/>' % OL]
	rnd = random.Random(5)
	for _ in range(16):
		b.append('<circle cx="%s" cy="%s" r="%s" fill="#7a4a20" opacity="0.6"/>' % (f(rnd.uniform(34, 106)), f(rnd.uniform(32, 104)), f(rnd.uniform(1.8, 3.6))))
	return svg(w, h, "\n".join(b), defs)


def exec_star():
	w, h = 80, 80
	defs = rad("st", 0.5, 0.45, 0.6, [(0, "#ffffff"), (0.45, "#e6dcff"), (1, "#9b6bd6")])
	b = [star(40, 42, 36, 15, "url(#st)", "#5a3d9a", 3.5), sparkle(32, 32, 8, "#ffffff")]
	return svg(w, h, "\n".join(b), defs)


def exec_tophat():
	w, h = 220, 190
	defs = lin("hat", 0, 0, 1, 0, [(0, "#1a1424"), (0.35, "#3a3050"), (0.6, "#221a30"), (1, "#100c18")])
	b = ['<ellipse cx="110" cy="172" rx="104" ry="16" fill="%s" opacity="0.3"/>' % OL,
		'<path d="M50,26 C50,12 170,12 170,26 L162,150 L58,150 Z" fill="url(#hat)" stroke="%s" stroke-width="5" stroke-linejoin="round"/>' % OL,
		'<ellipse cx="110" cy="24" rx="60" ry="12" fill="#2e2440" stroke="%s" stroke-width="4"/>' % OL,
		'<path d="M56,110 L164,110 L162,140 L58,140 Z" fill="#7d44c8" stroke="%s" stroke-width="4" stroke-linejoin="round"/>' % OL,
		star(132, 125, 13, 5.5, "#e8e6ff", OL, 2.5),
		'<path d="M6,158 C6,140 214,140 214,158 C214,176 6,176 6,158 Z" fill="#221a30" stroke="%s" stroke-width="5"/>' % OL,
		'<path d="M74,34 L70,104" stroke="#ffffff" stroke-width="6" stroke-linecap="round" opacity="0.25"/>']
	return svg(w, h, "\n".join(b), defs)


def exec_poof():
	w, h = 280, 220
	circles = [(140, 110, 70), (80, 120, 50), (200, 118, 54), (110, 70, 46), (176, 72, 44), (60, 160, 34), (220, 160, 36), (140, 168, 46)]
	b = []
	for cx, cy, r in circles:
		b.append('<circle cx="%d" cy="%d" r="%d" fill="#9b84d6"/>' % (cx, cy, r + 5))
	for cx, cy, r in circles:
		b.append('<circle cx="%d" cy="%d" r="%d" fill="#f4f0ff"/>' % (cx, cy, r))
	for cx, cy, r in circles[:5]:
		b.append('<circle cx="%d" cy="%d" r="%d" fill="#ffffff" opacity="0.8"/>' % (cx - r * 0.3, cy - r * 0.3, r * 0.4))
	for cx, cy, r in circles:
		b.append('<path d="M%s,%s A%s,%s 0 0 0 %s,%s" fill="none" stroke="#c8b8f0" stroke-width="6" opacity="0.7"/>' % (
			f(cx - r * 0.7), f(cy + r * 0.5), f(r), f(r), f(cx + r * 0.7), f(cy + r * 0.5)))
	b.append(sparkle(40, 50, 16, "#d9c8ff"))
	b.append(sparkle(250, 60, 12, "#ffffff"))
	b.append(sparkle(236, 196, 14, "#d9c8ff"))
	return svg(w, h, "\n".join(b))


def exec_sky():
	W, H = 1280, 720
	defs = (lin("sky", 0, 0, 0, 1, [(0, "#070514"), (0.55, "#1d1040"), (1, "#4a2a6a")])
		+ rad("moon", 0.4, 0.4, 0.6, [(0, "#fffbe8"), (1, "#e8dcb0")])
		+ rad("mglow", 0.5, 0.5, 0.5, [(0, "#fff6c8", 0.35), (1, "#fff6c8", 0)])
		+ lin("tent", 0, 0, 1, 0, [(0, "#000000", 0.4), (0.5, "#000000", 0), (1, "#000000", 0.45)]))
	b = ['<rect width="%d" height="%d" fill="url(#sky)"/>' % (W, H)]
	rnd = random.Random(21)
	for _ in range(160):
		x, y = rnd.uniform(0, W), rnd.uniform(0, 520)
		b.append('<circle cx="%s" cy="%s" r="%s" fill="#ffffff" opacity="%s"/>' % (f(x), f(y), f(rnd.uniform(0.8, 2.2)), f(rnd.uniform(0.3, 0.9))))
	for _ in range(10):
		b.append(sparkle(rnd.uniform(40, 1240), rnd.uniform(30, 420), rnd.uniform(5, 9), "#e6dcff", 0.9))
	b.append('<circle cx="1080" cy="120" r="120" fill="url(#mglow)"/>')
	b.append('<circle cx="1080" cy="120" r="56" fill="url(#moon)"/>')
	b.append('<circle cx="1062" cy="104" r="10" fill="#e0d4a8" opacity="0.7"/><circle cx="1098" cy="138" r="7" fill="#e0d4a8" opacity="0.7"/>')
	# hills + resort silhouette
	b.append('<path d="M0,560 C200,500 360,540 520,520 C700,496 860,540 1040,510 C1140,494 1220,520 1280,512 L1280,720 L0,720 Z" fill="#1a1030"/>')
	b.append('<path d="M0,600 C180,580 340,600 640,590 C900,580 1100,600 1280,590 L1280,720 L0,720 Z" fill="#120a24"/>')
	for x, ww, hh in [(90, 60, 70), (160, 40, 50), (1110, 70, 80), (1190, 50, 54)]:
		b.append('<rect x="%d" y="%d" width="%d" height="%d" fill="#120a24"/>' % (x, 600 - hh, ww, hh))
		b.append('<rect x="%d" y="%d" width="8" height="10" fill="#ffd166" opacity="0.8"/>' % (x + 12, 600 - hh + 16))
	# big top exterior
	n = 10
	base_l, base_r, base_y = 370, 910, 650
	apex = (640, 410)
	b.append('<ellipse cx="640" cy="660" rx="300" ry="26" fill="#000000" opacity="0.4"/>')
	for i in range(n):
		xa = base_l + (base_r - base_l) * i / n
		xb = base_l + (base_r - base_l) * (i + 1) / n
		col = "#c0303f" if i % 2 == 0 else "#f0dcb4"
		b.append('<path d="M640,410 C%s,%s %s,%s %s,%d L%s,%d C%s,%s %s,%s 640,410 Z" fill="%s"/>' % (
			f(640 + (xa - 640) * 0.5), "470", f(xa), "560", f(xa), base_y, f(xb), base_y, f(xb), "560", f(640 + (xb - 640) * 0.5), "470", col))
	b.append('<path d="M640,410 C560,470 %d,560 %d,%d L%d,%d C%d,560 720,470 640,410 Z" fill="url(#tent)" stroke="%s" stroke-width="5" stroke-linejoin="round"/>' % (
		base_l, base_l, base_y, base_r, base_y, base_r, OL))
	for i in range(12):
		cx = base_l + 20 + i * 45
		b.append('<path d="M%d,%d A22,16 0 0 0 %d,%d Z" fill="#d8a93a" stroke="%s" stroke-width="3"/>' % (cx - 22, base_y - 74, cx + 22, base_y - 74, OL))
	b.append('<path d="M600,%d L600,%d Q640,%d 680,%d L680,%d Z" fill="#1a0a20" stroke="%s" stroke-width="4"/>' % (base_y, base_y - 70, base_y - 110, base_y - 70, base_y, OL))
	b.append('<line x1="640" y1="410" x2="640" y2="360" stroke="%s" stroke-width="5"/>' % OL)
	b.append('<polygon points="640,360 690,372 640,386" fill="#ffb347" stroke="%s" stroke-width="3.5" stroke-linejoin="round"/>' % OL)
	# light strings
	for side in (-1, 1):
		for i in range(9):
			t = (i + 1) / 10.0
			x = 640 + side * 330 * t
			y = 410 + 260 * t - 60 * t * (1 - t) * 4
			b.append('<circle cx="%s" cy="%s" r="5" fill="#fff3a0"/>' % (f(x), f(y)))
	return svg(W, H, "\n".join(b), defs)


# ------------------------------------------------------------------ game over: Mochi's Last Soak
def soak_bg():
	W, H = 1280, 720
	defs = (lin("wall", 0, 0, 0, 1, [(0, "#1a0f2e"), (1, "#2e1636")])
		+ lin("pipe", 0, 0, 0, 1, [(0, "#e09a60"), (0.5, "#b8662e"), (1, "#6a3414")])
		+ rad("lamp", 0.5, 0.5, 0.5, [(0, "#ff4f6d", 0.7), (1, "#ff4f6d", 0)])
		+ rad("vig", 0.5, 0.45, 0.75, [(0, "#000000", 0), (1, "#000000", 0.6)]))
	b = ['<rect width="%d" height="%d" fill="url(#wall)"/>' % (W, H)]
	for y in range(0, 560, 48):
		b.append('<line x1="0" y1="%d" x2="%d" y2="%d" stroke="#3a2450" stroke-width="3"/>' % (y, W, y))
		off = 0 if (y // 48) % 2 == 0 else 32
		for x in range(off, W, 64):
			b.append('<line x1="%d" y1="%d" x2="%d" y2="%d" stroke="#3a2450" stroke-width="3"/>' % (x, y, x, y + 48))
	# pipes
	b.append('<rect x="0" y="150" width="%d" height="30" fill="url(#pipe)" stroke="%s" stroke-width="4"/>' % (W, OL))
	for x in (150, 1130):
		b.append('<rect x="%d" y="150" width="30" height="410" fill="url(#pipe)" stroke="%s" stroke-width="4"/>' % (x, OL))
		b.append('<rect x="%d" y="140" width="50" height="50" rx="8" fill="#8a4a1c" stroke="%s" stroke-width="4"/>' % (x - 10, OL))
	for x in (380, 900):
		b.append('<circle cx="%d" cy="165" r="26" fill="#d8dde8" stroke="%s" stroke-width="5"/>' % (x, OL))
		b.append('<line x1="%d" y1="165" x2="%d" y2="150" stroke="#ff4f6d" stroke-width="4" stroke-linecap="round"/>' % (x, x + 14))
		b.append('<circle cx="%d" cy="165" r="4" fill="%s"/>' % (x, OL))
	# Snapjaw crest (caiman head in a top hat)
	cx, cy = 640, 92
	b.append('<circle cx="%d" cy="%d" r="62" fill="#2a1a3a" stroke="#ffd166" stroke-width="6"/>' % (cx, cy))
	b.append('<path d="M%d,%d C%d,%d %d,%d %d,%d L%d,%d C%d,%d %d,%d %d,%d Z" fill="#43a047" stroke="%s" stroke-width="4" stroke-linejoin="round"/>' % (
		cx - 40, cy + 6, cx - 40, cy - 22, cx, cy - 26, cx, cy - 26, cx, cy + 34, cx - 24, cy + 34, cx - 40, cy + 26, cx - 40, cy + 6, OL))
	b.append('<path d="M%d,%d C%d,%d %d,%d %d,%d L%d,%d C%d,%d %d,%d %d,%d Z" fill="#c8ccd8" stroke="%s" stroke-width="4" stroke-linejoin="round"/>' % (
		cx, cy - 26, cx, cy - 26, cx + 40, cy - 22, cx + 40, cy + 6, cx + 40, cy + 26, cx + 24, cy + 34, cx, cy + 34, cx, cy - 26, OL))
	b.append('<circle cx="%d" cy="%d" r="8" fill="#ff2040" stroke="%s" stroke-width="3"/>' % (cx + 18, cy - 6, OL))
	b.append('<circle cx="%d" cy="%d" r="8" fill="#ffffff" stroke="%s" stroke-width="3"/>' % (cx - 18, cy - 6, OL))
	b.append('<path d="M%d,%d L%d,%d L%d,%d L%d,%d L%d,%d L%d,%d L%d,%d" fill="none" stroke="#ffffff" stroke-width="3.5" stroke-linejoin="round"/>' % (
		cx - 26, cy + 18, cx - 18, cy + 26, cx - 10, cy + 18, cx - 2, cy + 26, cx + 6, cy + 18, cx + 14, cy + 26, cx + 22, cy + 18))
	b.append('<rect x="%d" y="%d" width="44" height="30" fill="#120a14" stroke="%s" stroke-width="4"/>' % (cx - 22, cy - 62, OL))
	b.append('<rect x="%d" y="%d" width="76" height="9" rx="3" fill="#120a14" stroke="%s" stroke-width="4"/>' % (cx - 38, cy - 34, OL))
	b.append('<rect x="%d" y="%d" width="44" height="7" fill="#c0303f"/>' % (cx - 22, cy - 42))
	# hazard stripe band
	b.append('<rect x="0" y="556" width="%d" height="34" fill="#ffd166" stroke="%s" stroke-width="4"/>' % (W, OL))
	for x in range(-40, W + 40, 56):
		b.append('<polygon points="%s" fill="#1a0f1e"/>' % pts([(x, 590), (x + 28, 590), (x + 56, 558), (x + 28, 558)]))
	# floor tiles
	b.append('<rect x="0" y="590" width="%d" height="130" fill="#241430"/>' % W)
	for i in range(0, 24):
		for j in range(3):
			if (i + j) % 2 == 0:
				b.append('<rect x="%d" y="%d" width="56" height="44" fill="#341c44"/>' % (i * 56 - (j * 20), 590 + j * 44))
	# warning lamps
	for x in (70, 1210):
		b.append('<circle cx="%d" cy="300" r="70" fill="url(#lamp)"/>' % x)
		b.append('<path d="M%d,320 A24,24 0 0 1 %d,320 Z" fill="#ff4f6d" stroke="%s" stroke-width="4"/>' % (x - 24, x + 24, OL))
		b.append('<rect x="%d" y="318" width="60" height="14" rx="4" fill="#3a3a48" stroke="%s" stroke-width="4"/>' % (x - 30, OL))
	b.append('<rect width="%d" height="%d" fill="url(#vig)"/>' % (W, H))
	return svg(W, H, "\n".join(b), defs)


def soak_stove():
	w, h = 720, 260
	defs = (lin("iron", 0, 0, 0, 1, [(0, "#4a4458"), (1, "#1c1824")])
		+ rad("ov", 0.5, 0.5, 0.6, [(0, "#ffd166"), (0.6, "#ff7a2a"), (1, "#a8281a")]))
	b = []
	b.append('<rect x="20" y="40" width="680" height="214" rx="16" fill="url(#iron)" stroke="%s" stroke-width="6"/>' % OL)
	b.append('<rect x="6" y="26" width="708" height="28" rx="8" fill="#5a5468" stroke="%s" stroke-width="6"/>' % OL)
	# burner grate
	b.append('<ellipse cx="360" cy="26" rx="220" ry="16" fill="#1a1620" stroke="%s" stroke-width="5"/>' % OL)
	for x in range(170, 560, 48):
		b.append('<rect x="%d" y="10" width="10" height="20" rx="3" fill="#3a3448" stroke="%s" stroke-width="3"/>' % (x, OL))
	# oven door with glowing window
	b.append('<rect x="200" y="86" width="320" height="140" rx="14" fill="#2a2434" stroke="%s" stroke-width="5"/>' % OL)
	b.append('<rect x="232" y="110" width="256" height="84" rx="10" fill="url(#ov)" stroke="%s" stroke-width="5"/>' % OL)
	b.append('<rect x="250" y="96" width="220" height="10" rx="5" fill="#c8ccd8" stroke="%s" stroke-width="3"/>' % OL)
	for x in (80, 640):
		b.append('<circle cx="%d" cy="150" r="30" fill="#c0303f" stroke="%s" stroke-width="5"/>' % (x, OL))
		b.append('<circle cx="%d" cy="150" r="8" fill="#ffd166" stroke="%s" stroke-width="3"/>' % (x, OL))
	b.append('<path d="M0,0" />')
	return svg(w, h, "\n".join(b), defs)


def soak_knob():
	w, h = 80, 80
	b = ['<circle cx="40" cy="40" r="34" fill="#e8e6ff" stroke="%s" stroke-width="5"/>' % OL,
		'<rect x="34" y="6" width="12" height="38" rx="6" fill="#ff4f6d" stroke="%s" stroke-width="4"/>' % OL,
		'<circle cx="40" cy="40" r="8" fill="#8f98aa" stroke="%s" stroke-width="3"/>' % OL]
	return svg(w, h, "\n".join(b))


def soak_flame():
	w, h = 140, 170
	defs = (lin("fo", 0, 0, 0, 1, [(0, "#ffd166"), (0.5, "#ff7a2a"), (1, "#e2302a")])
		+ lin("fi", 0, 0, 0, 1, [(0, "#fffbe0"), (1, "#ffd166")]))
	b = ['<path d="M70,4 C86,40 128,70 124,116 C120,150 96,166 70,166 C44,166 18,150 16,116 C14,84 40,70 46,40 C54,58 60,62 64,66 C64,44 62,26 70,4 Z" fill="url(#fo)" stroke="#a8281a" stroke-width="4" stroke-linejoin="round"/>',
		'<path d="M70,60 C80,84 102,100 100,126 C98,148 84,158 70,158 C56,158 42,148 40,126 C40,106 58,96 62,80 C66,88 68,90 70,92 C70,80 66,72 70,60 Z" fill="url(#fi)"/>',
		'<ellipse cx="70" cy="150" rx="24" ry="12" fill="#5ab4ff" opacity="0.85"/>']
	return svg(w, h, "\n".join(b), defs)


def soak_tub_back():
	w, h = 620, 120
	b = ['<path d="M24,64 C24,20 596,20 596,64 L572,64 C572,40 48,40 48,64 Z" fill="#dfe8f4" stroke="%s" stroke-width="6" stroke-linejoin="round"/>' % OL,
		'<path d="M48,64 C48,40 572,40 572,64" fill="none" stroke="#9fb0c8" stroke-width="8"/>']
	return svg(w, h, "\n".join(b))


def soak_tub_front():
	w, h = 620, 340
	defs = (lin("en", 0, 0, 0, 1, [(0, "#ffffff"), (0.6, "#e4ecf6"), (1, "#a8b8d0")])
		+ lin("wt", 0, 0, 0, 1, [(0, "#8ff5ea", 0.95), (1, "#3ec8d0", 0.97)])
		+ lin("gold", 0, 0, 0, 1, [(0, "#ffe08a"), (1, "#b8862a")]))
	b = []
	# water surface (in front of the bather)
	b.append('<ellipse cx="310" cy="66" rx="266" ry="30" fill="url(#wt)"/>')
	b.append('<path d="M70,70 C140,60 200,82 270,70 C340,58 420,84 550,66" fill="none" stroke="#e8fffb" stroke-width="5" stroke-linecap="round" opacity="0.9"/>')
	# claw feet
	for x in (110, 510):
		b.append('<path d="M%d,270 C%d,300 %d,318 %d,330 L%d,330 C%d,318 %d,300 %d,270 Z" fill="url(#gold)" stroke="%s" stroke-width="5" stroke-linejoin="round"/>' % (
			x - 26, x - 30, x - 40, x - 44, x + 20, x + 10, x + 26, x + 26, OL))
	# tub body
	b.append('<path d="M14,70 C14,96 30,100 34,140 C40,220 90,280 170,286 L450,286 C530,280 580,220 586,140 C590,100 606,96 606,70 C606,104 14,104 14,70 Z" fill="url(#en)" stroke="%s" stroke-width="6" stroke-linejoin="round"/>' % OL)
	# rolled front rim
	b.append('<path d="M14,70 C14,108 606,108 606,70 L606,64 C606,98 14,98 14,64 Z" fill="#ffffff" stroke="%s" stroke-width="5" stroke-linejoin="round"/>' % OL)
	b.append('<path d="M70,150 C90,220 130,256 190,264" fill="none" stroke="#ffffff" stroke-width="12" stroke-linecap="round" opacity="0.8"/>')
	b.append('<path d="M548,150 C536,200 520,230 494,250" fill="none" stroke="#a8b8d0" stroke-width="8" stroke-linecap="round" opacity="0.7"/>')
	b.append(star(310, 190, 22, 9, "#3ee0d0", OL, 3.5))
	return svg(w, h, "\n".join(b), defs)


def soak_duck():
	w, h = 120, 110
	defs = rad("dk", 0.4, 0.35, 0.7, [(0, "#fff6a0"), (0.6, "#ffd23d"), (1, "#f0a810")])
	b = ['<ellipse cx="64" cy="96" rx="44" ry="8" fill="#000000" opacity="0.2"/>',
		'<path d="M20,64 C16,90 40,100 66,100 C96,100 112,88 112,70 C112,56 104,50 96,54 C96,40 88,36 80,40 L60,52 C46,52 28,54 20,64 Z" fill="url(#dk)" stroke="%s" stroke-width="5" stroke-linejoin="round"/>' % OL,
		'<circle cx="46" cy="38" r="26" fill="url(#dk)" stroke="%s" stroke-width="5"/>' % OL,
		'<path d="M24,40 C10,38 2,44 4,50 C10,54 20,52 26,48 Z" fill="#ff8a30" stroke="%s" stroke-width="4" stroke-linejoin="round"/>' % OL,
		'<circle cx="42" cy="32" r="5" fill="%s"/><circle cx="40.5" cy="30.5" r="1.8" fill="#ffffff"/>' % OL,
		'<path d="M66,70 C76,62 92,64 96,74 C88,80 74,80 66,70 Z" fill="#f0b820" stroke="%s" stroke-width="3.5" stroke-linejoin="round"/>' % OL,
		'<ellipse cx="38" cy="24" rx="8" ry="5" fill="#ffffff" opacity="0.7"/>']
	return svg(w, h, "\n".join(b), defs)


def soak_thermo():
	w, h = 130, 470
	defs = lin("pl", 0, 0, 1, 0, [(0, "#3a2a4a"), (1, "#22162e")])
	b = ['<rect x="4" y="4" width="122" height="462" rx="22" fill="url(#pl)" stroke="#ffd166" stroke-width="5"/>',
		'<rect x="47" y="22" width="36" height="372" rx="18" fill="#1a0f20" stroke="%s" stroke-width="5"/>' % OL,
		# red zone marker
		'<rect x="22" y="40" width="14" height="96" rx="5" fill="#ff4f6d" stroke="%s" stroke-width="3"/>' % OL,
		'<rect x="22" y="136" width="14" height="110" rx="5" fill="#ffb347" stroke="%s" stroke-width="3"/>' % OL,
		'<rect x="22" y="246" width="14" height="130" rx="5" fill="#3ee0d0" stroke="%s" stroke-width="3"/>' % OL]
	for i in range(13):
		y = 52 + i * 26
		ln = 18 if i % 2 == 0 else 10
		b.append('<line x1="90" y1="%d" x2="%d" y2="%d" stroke="#e8e6ff" stroke-width="3.5" stroke-linecap="round"/>' % (y, 90 + ln, y))
	b.append('<circle cx="65" cy="420" r="38" fill="#ff4f6d" stroke="%s" stroke-width="6"/>' % OL)
	b.append('<circle cx="54" cy="408" r="10" fill="#ffffff" opacity="0.6"/>')
	return svg(w, h, "\n".join(b), defs)


def main():
	os.makedirs(OUT, exist_ok=True)
	out = []
	out.append(write("title_drop", title_drop()))
	out.append(write("title_yuzu", title_yuzu()))
	out.append(write("title_wave", title_wave()))
	out.append(write("title_sparkle", title_sparkle()))
	out.append(write("exec_tent", exec_tent()))
	out.append(write("exec_footlights", exec_footlights()))
	out.append(write("exec_curtain_l", exec_curtain("l")))
	out.append(write("exec_curtain_r", exec_curtain("r")))
	out.append(write("exec_spot", exec_spot()))
	for s in "abc":
		out.append(write("exec_box_%s_l" % s, exec_box_half(s, "l")))
		out.append(write("exec_box_%s_r" % s, exec_box_half(s, "r")))
	out.append(write("exec_stand", exec_stand()))
	out.append(write("exec_saw", exec_saw()))
	out.append(write("exec_feet", exec_feet()))
	out.append(write("exec_lever", exec_lever()))
	out.append(write("exec_trapdoor", exec_trapdoor()))
	out.append(write("exec_hole", exec_hole()))
	out.append(write("exec_glass_back", exec_glass_back()))
	out.append(write("exec_glass_front", exec_glass_front()))
	out.append(write("exec_cork", exec_cork()))
	out.append(write("exec_star", exec_star()))
	out.append(write("exec_tophat", exec_tophat()))
	out.append(write("exec_poof", exec_poof()))
	out.append(write("exec_sky", exec_sky()))
	out.append(write("exec_soak_bg", soak_bg()))
	out.append(write("exec_soak_stove", soak_stove()))
	out.append(write("exec_soak_knob", soak_knob()))
	out.append(write("exec_soak_flame", soak_flame()))
	out.append(write("exec_soak_tub_back", soak_tub_back()))
	out.append(write("exec_soak_tub_front", soak_tub_front()))
	out.append(write("exec_soak_duck", soak_duck()))
	out.append(write("exec_soak_thermo", soak_thermo()))
	print("wrote %d files" % len(out))


if __name__ == "__main__":
	main()
