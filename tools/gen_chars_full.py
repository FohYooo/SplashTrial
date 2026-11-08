#!/usr/bin/env python3
"""
SPLASH TRIAL 3D -- full-body character art for the walk-around rooms.

Writes art/chars_full/<id>_<expr>.svg (640x920, transparent) for all 16 characters in the expressions the
3D standees use (normal, sad, angry).  Heads, hats, faces and props come straight from tools/gen_chars.py,
so a standee always matches its dialogue portrait; this file only replaces the bust's body with a full one:
torso, arms and paws, the rest of each outfit, legs and shoes.

Canvas: the feet of every character stand on the same baseline (y = BASE, just above the bottom edge), and
one art pixel at scale 1 is the same world size as in the bust standee.  Relative heights are baked into the
art through each character's `s`, so the game can use one quad size for everybody.

Usage:
    python3 tools/gen_chars_full.py              # all characters
    python3 tools/gen_chars_full.py mochi bruno  # only some
    python3 tools/gen_chars_full.py --faces      # (not used by the game) no-op guard
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gen_chars as B  # noqa: E402
from gen_chars import P, C, E, R, G, pt, n, smooth, darker, lighter, mix, OUT, WHITE  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUTDIR = os.path.join(ROOT, 'art', 'chars_full')
EXPRS = ['normal', 'sad', 'angry']

W_, H_ = 640, 920
CX = 320
BASE = 916          # canvas y of the ground line
GY = 742            # default ground line in bust space (before gen_chars.SHIFT)
CUR = {}            # the spec of the portrait being drawn


def render_full(self, body):
	s = CUR.get('s', 1.0)
	gy = CUR.get('gy', GY) + B.SHIFT
	tf = 'translate(%s %s) scale(%s) translate(-240 %s)' % (n(CX), n(BASE), B.n3(s), n(-gy))
	return ('<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d" viewBox="0 0 %d %d">'
		'<defs>%s</defs>%s</svg>\n') % (W_, H_, W_, H_, ''.join(self.defs), G(body, tf=tf))


B.Doc.render = render_full

# ============================================================================ feet


def dome(x, gy, w, h):
	return 'M%s L%s C%s %s %s C%s %s %sZ' % (pt((x - w, gy)), pt((x + w, gy)), pt((x + w + 5, gy - h * 0.72)), pt((x + w * 0.62, gy - h)), pt((x, gy - h)),
		pt((x - w * 0.62, gy - h)), pt((x - w - 5, gy - h * 0.72)), pt((x - w, gy)))


def shoe(d, c, fb, x, side, gy, w):
	kind = fb.get('shoe', 'shoe')
	col = fb.get('shoe_c', '#4a2f20')
	col2 = fb.get('shoe_c2', WHITE)
	x2 = x + side * 8
	s = ''
	if kind in ('paw', 'geta'):
		fy = gy - (14 if kind == 'geta' else 0)
		if kind == 'geta':
			s += R(x2 - w - 8, gy - 16, 2 * w + 16, 10, rx=3, fill='#c98b4a', st=OUT, sw=4)
			for dx in (-w * 0.55, w * 0.55):
				s += R(x2 + dx - 8, gy - 8, 16, 8, fill='#a86a32', st=OUT, sw=3.5)
		s += P(dome(x2, fy, w, 34), fill=c['fur'], st=OUT, sw=5.5)
		for k in (-0.36, 0.36):
			s += P('M%s L%s' % (pt((x2 + w * k, fy - 15)), pt((x2 + w * k, fy - 1))), st=OUT, sw=3.5)
		if kind == 'geta':
			s += P('M%s Q%s %s' % (pt((x2 - w * 0.7, fy - 18)), pt((x2, fy - 30)), pt((x2 + w * 0.7, fy - 18))), st=OUT, sw=9) + P(
				'M%s Q%s %s' % (pt((x2 - w * 0.7, fy - 18)), pt((x2, fy - 30)), pt((x2 + w * 0.7, fy - 18))), st='#d8343a', sw=4.5)
		return s
	if kind == 'claw':
		col = fb['paw_c'][side]
		s += P(dome(x2, gy, w + 6, 40), fill=col, st=OUT, sw=5.5)
		for k in (-0.62, 0, 0.62):
			tx = x2 + w * k
			s += P(B.poly([(tx - 9, gy - 6), (tx + 9, gy - 6), (tx + side * 3, gy + 2)]), fill='#f4f2e4', st=OUT, sw=3)
		return s
	h = {'boot': 74, 'rain': 70, 'clog': 40, 'slipper': 36, 'sneaker': 40, 'mary': 32, 'spat': 46}.get(kind, 38)
	s += P(dome(x2, gy, w, h), fill=col, st=OUT, sw=5.5)
	k = d.clip(dome(x2, gy, w, h))
	inner = R(x2 - w - 10, gy - 9, 2 * w + 20, 10, fill=darker(col, 0.4) if kind != 'sneaker' else WHITE, st=None)
	inner += E(x2 - w * 0.34, gy - h * 0.62, w * 0.3, h * 0.13, fill=WHITE, st=None, op=0.35)
	if kind == 'boot':    # wrestling boot: stripe and laces
		inner += R(x2 - w - 10, gy - 66, 2 * w + 20, 12, fill=col2, st=None)
		for i in range(4):
			yy = gy - 48 + i * 10
			inner += P('M%s L%s' % (pt((x2 - 10, yy)), pt((x2 + 10, yy + 5))), st=col2, sw=3)
	elif kind == 'sneaker':
		inner += P('M%s L%s' % (pt((x2 - w * 0.7, gy - 28)), pt((x2 + w * 0.5, gy - 12))), st=col2, sw=6)
	elif kind == 'clog':
		for (dx, dy) in ((-12, 26), (0, 30), (12, 26), (-6, 20), (6, 20)):
			inner += C(x2 + dx, gy - dy, 2.2, fill=darker(col, 0.3), st=None)
	elif kind == 'mary':
		inner += R(x2 - w - 10, gy - 26, 2 * w + 20, 6, fill=darker(col, 0.25), st=None)
	elif kind == 'spat':
		inner += R(x2 - w - 10, gy - 48, 2 * w + 20, 28, fill=col2, st=None)
		for yy in (gy - 42, gy - 30):
			inner += C(x2 + side * w * 0.4, yy, 2.6, fill=OUT, st=None)
	elif kind == 'shoe':
		for i in range(3):
			yy = gy - 30 + i * 7
			inner += P('M%s L%s' % (pt((x2 - 9, yy)), pt((x2 + 9, yy))), st=col2, sw=2.5, op=0.85)
	s += G(inner, clip=k) + P(dome(x2, gy, w, h), st=OUT, sw=5.5)
	if kind == 'slipper':
		for (dx, dy, r) in ((-w * 0.5, 30, 9), (0, 36, 11), (w * 0.5, 30, 9)):
			s += C(x2 + dx, gy - dy, r, fill=col2, st=OUT, sw=3.5)
		for (dx, dy, r) in ((-w * 0.5, 30, 9), (0, 36, 11), (w * 0.5, 30, 9)):
			s += C(x2 + dx, gy - dy, r - 2, fill=col2, st=None)
	return s


def legs(d, c, e, fb, W):
	gy, hem = fb.get('gy', GY), fb['hem']
	ldx = fb.get('ldx', 60) * W
	lw = fb.get('lw', 33) * W ** 0.5
	top = hem - 26
	ankle = gy - 22
	pants = fb.get('pants')
	pant_end = fb.get('pant_end', ankle)
	leg_col = fb.get('leg', c['fur'])
	flare = fb.get('flare', 0)
	s = ''
	for side in (1, -1):
		x = 240 + side * ldx
		if pant_end < ankle or not pants:
			leg = R(x - lw + 3, top, 2 * lw - 6, ankle - top + 6, rx=6, fill=leg_col, st=OUT, sw=5.5)
			s += leg
		s += shoe(d, c, fb, x, side, gy, lw + fb.get('foot', 10))
		if pants:
			pp = 'M%s L%s L%s L%s Z' % (pt((x - lw, top)), pt((x + lw, top)), pt((x + lw + flare, pant_end)), pt((x - lw - flare, pant_end)))
			k = d.clip(pp)
			inner = P(pp, fill=pants, st=None)
			if fb.get('pants_fx'):
				inner += fb['pants_fx'](x, lw + flare, top, pant_end)
			inner += R(x + lw * 0.3, top, lw * 1.2 + flare, pant_end - top + 4, fill=B.NIGHT_SH, st=None, op=0.2)
			inner += R(x - lw - flare - 4, pant_end - 11, 2 * lw + 2 * flare + 8, 11, fill=darker(pants, 0.28), st=None)
			s += G(inner, clip=k) + P(pp, st=OUT, sw=5.5)
		s += R(x - lw, hem - 2, 2 * lw, 24, fill=B.NIGHT_SH, st=None, op=0.3)
	return s


# ============================================================================ body

SHOULDER_DEF = [(64, 298), (120, 318), (162, 356)]


def side_pts(fb, sgn, W):
	kind = fb.get('arms', {}).get(sgn, 'down')
	hem, hw = fb['hem'], fb.get('hem_w', 150)
	top = fb.get('top', SHOULDER_DEF)
	if kind == 'bare':
		low = [(150, 372), (132, 440), (118, 520), (hw * 0.9, hem - 50), (hw, hem)]
		top = top[:2]
	elif kind == 'up':
		low = [(180, 416), (176, 490), (152, 566), (hw, hem)]
	else:
		low = [(182, 416), (192, 500), (190, 568), (180, 596), (128, 600), (132, 618), (hw, hem)]
	return [(240 + sgn * dx * W, y) for dx, y in top + low]


def body_d(fb, W):
	R_ = side_pts(fb, 1, W)
	L_ = side_pts(fb, -1, W)
	return smooth([(240, 292)] + R_ + [(240, fb['hem'] + 6)] + L_[::-1], k=0.85)


def tube(a, b, ctrl, col, w):
	d_ = 'M%s Q%s %s' % (pt(a), pt(ctrl), pt(b))
	return P(d_, st=OUT, sw=w + 11) + P(d_, st=col, sw=w)


def draw_body_full(d, c, e):
	fb = c.get('fb') or CUR
	W = fb['w']
	X = lambda x: 240 + (x - 240) * W
	bp = body_d(fb, W)
	bc = d.clip(bp)
	s = ''
	if 'behind' in fb:
		s += fb['behind'](d, c, e)
	s += legs(d, c, e, fb, W)
	s += P(bp, fill=c['fur'], st=None)
	scale = 'translate(240 0) scale(%s 1) translate(-240 0)' % B.n3(W)
	inner = ''
	if 'outfit' in c:
		inner += G(c['outfit'](d, c, e), tf=scale)
	if 'lower' in fb:
		inner += G(fb['lower'](d, c, e, fb), tf=scale)
	# hard cel shadow down the shadow side + the head's cast shadow on the chest
	hem = fb['hem']
	# (the band follows the outer arm only: cuff-inner points would bend it into a stray wedge at the hip)
	edge = [p for p in side_pts(fb, 1, W) if p[1] <= 597]
	sh = smooth(edge + [(240 + fb.get('hem_w', 150) * W + 6, hem + 8), (240 + (fb.get('hem_w', 150) - 52) * W, hem + 8)]
		+ [(x - 54 * W, y) for x, y in reversed(edge[2:])], k=0.7)
	inner += P(sh, fill=B.NIGHT_SH, st=None, op=0.26)
	inner += E(240, 338, 128 * c.get('hs', 1.0), 33, fill=B.NIGHT_SH, st=None, op=0.3)
	if e == 'sad':
		inner += P(bp, fill=B.SAD_BLUE, st=None, op=0.16)
	for sgn in (-1, 1):
		kind = fb.get('arms', {}).get(sgn, 'down')
		if kind == 'down':
			inner += P('M%s C%s %s %s' % (pt((240 + sgn * 138 * W, 404)), pt((240 + sgn * 128 * W, 470)),
				pt((240 + sgn * 124 * W, 540)), pt((240 + sgn * 128 * W, 598))), st=OUT, sw=4.5, op=0.9)
	peak = 0.95 if e == 'angry' else 0.7
	inner += P(bp, st=B.rim_grad(d, e, (X(250), 0), (X(420), 0), peak, 0.3), sw=22 if e == 'angry' else 17)
	s += G(inner, clip=bc) + P(bp, st=OUT, sw=B.SIL)
	# hands: hanging paws at the cuffs, or a bent forearm reaching up to a held prop (the prop's own paw is drawn in `front`)
	for sgn in (-1, 1):
		kind = fb.get('arms', {}).get(sgn, 'down')
		col = fb.get('paw_c', {}).get(sgn, c['fur'])
		glove = fb.get('glove')
		if kind == 'down':
			x, y = 240 + sgn * 156 * W, 611
			s += P('M%s L%s' % (pt((240 + sgn * 128 * W, 596)), pt((240 + sgn * 182 * W, 594))), st=OUT, sw=4.5, op=0.85)
			s += B.paw(x, y, col, -sgn * 6, 25, 22, glove=glove)
			if fb.get('band'):
				s += R(x - 26, 590, 52, 13, rx=4, fill=fb['band'], st=OUT, sw=4)
		elif kind == 'up':
			hand = fb['hand']
			s += tube((240 + sgn * 170 * W, 470), hand, (240 + sgn * 190 * W, 540), fb.get('sleeve', c['fur']), 44)
		elif kind == 'bare':
			sx, sy = 240 + sgn * 132 * W, 420
			ty = 566
			if sgn in fb.get('hand_up', ()):
				s += tube((sx, sy), fb['hand'], (sx + sgn * 34, sy + 72), c['fur'], 36)
			else:
				s += tube((sx, sy), (sx + sgn * 14, ty), (sx + sgn * 26, sy + 80), c['fur'], 36)
				s += B.paw(sx + sgn * 14, ty + 8, col, -sgn * 6, 23, 20)
	if 'over' in fb:
		s += fb['over'](d, c, e, fb, W)
	return s


B.draw_body = draw_body_full

# ============================================================================ lower outfits


def fill(col, y0, y1):
	return R(-80, y0, 640, y1 - y0, fill=col, st=None)


def rib_hem(col, y0, y1, x0=60, x1=420):
	s = R(-80, y0, 640, y1 - y0, fill=darker(col, 0.16), st=None) + P('M-80,%d L560,%d' % (y0, y0), st=OUT, sw=3.5, op=0.55)
	for x in range(x0, x1, 12):
		s += P('M%d,%d L%d,%d' % (x, y0 + 3, x, y1), st=darker(col, 0.42), sw=2, op=0.5)
	return s


def lower_mochi(d, c, e, fb):
	s = P('M170,560 L310,560 L326,612 L154,612 Z', st=darker(B.HOODIE, 0.4), sw=4, op=0.6, fill=darker(B.HOODIE, 0.08))
	return s + rib_hem(B.HOODIE, 620, 660)


def lower_coco(d, c, e, fb):
	return P('M-80,636 L560,636', st=OUT, sw=4, op=0.7)


def lower_wisp(d, c, e, fb):
	hem = fb['hem']
	s = fill(B.VIOLET, 650, hem + 20)
	for (x, y, r, a) in ((110, 650, 11, -85), (372, 660, 12, -75), (146, 696, 9, -95), (338, 702, 9, -90)):
		s += B.silver_star(x, y, r, a)
	s += P('M%s L%s L%s L%s Z' % (pt((222, 440)), pt((258, 440)), pt((316, hem + 14)), pt((164, hem + 14))), fill='#231a33', st=None)
	s += P('M222,440 L164,%d M258,440 L316,%d' % (hem + 14, hem + 14), st=OUT, sw=5)
	s += P('M222,440 L168,%d' % (hem + 8), st=B.VIOLET_D, sw=9, op=0.8, extra=' transform="translate(-6 0)"')
	s += P('M258,440 L312,%d' % (hem + 8), st=B.VIOLET_D, sw=9, op=0.8, extra=' transform="translate(6 0)"')
	s += B.fold('M130,580 Q140,650 128,%d' % hem, OUT, 4, 0.28) + B.fold('M352,580 Q342,650 354,%d' % hem, OUT, 4, 0.28)
	return s


def bruno_outfit_full(d, c, e):
	s = E(240, 420, 70, 60, fill=lighter(c['fur'], 0.12), st=None, op=0.6)
	s += P('M186,386 Q210,410 238,398', st=OUT, sw=4, op=0.55) + P('M242,398 Q270,410 294,386', st=OUT, sw=4, op=0.55)
	s += P('M92,420 Q106,380 142,360', st=OUT, sw=4, op=0.45) + P('M388,420 Q374,380 338,360', st=OUT, sw=4, op=0.45)
	sing = ('M148,312 L188,312 C192,370 206,422 222,452 Q240,462 258,452 C274,422 288,370 292,312 L332,312 '
		'C338,380 348,440 362,490 L370,670 L110,670 L118,490 C132,440 142,380 148,312 Z')
	k = d.clip(sing)
	s += P(sing, fill='#cf3434', st=None)
	s += G(P(sing, fill='#a82424', st=None, extra=' transform="translate(16 10)"') + P(sing, fill='#cf3434', st=None, extra=' transform="translate(-6 -2)"'), clip=k)
	neck = 'M188,312 C192,370 206,422 222,452 Q240,462 258,452 C274,422 288,370 292,312'
	edgeL = 'M148,312 C142,380 132,440 118,490 L110,670'
	edgeR = 'M332,312 C338,380 348,440 362,490 L370,670'
	for path in (neck, edgeL, edgeR):
		s += P(path, st=OUT, sw=11) + P(path, st=B.GOLD, sw=4.5)
	s += P(B.star(240, 530, 26, 0.45), fill=B.GOLD, st=OUT, sw=4)
	# champion's belt
	s += R(116, 596, 248, 40, rx=6, fill='#2a2a30', st=OUT, sw=4.5)
	s += P(smooth([(240, 586), (284, 594), (292, 616), (284, 638), (240, 646), (196, 638), (188, 616), (196, 594)]), fill=B.GOLD, st=OUT, sw=4.5)
	s += P(B.star(240, 616, 15, 0.45), fill='#fff3b0', st=OUT, sw=3)
	return s


def lower_lulu(d, c, e, fb):
	hem = fb['hem']
	s = fill('#ff86c2', 650, hem + 10)
	for x in range(60, 430, 54):
		s += P('M%d,500 Q%d,600 %d,%d' % (240 + (x - 240) * 0.45, x, x, hem), st='#e8609f', sw=3.5, op=0.6)
	pts = [(x, hem - 8) for x in range(60, 424, 34)]
	s += P(B.scallop(pts, 7, 1) + ' L424,%d L60,%d Z' % (hem + 20, hem + 20), fill='#fffaf4', st=OUT, sw=4)
	s += P('M60,%d L424,%d' % (hem - 22, hem - 22), st='#ff5da0', sw=6)
	for (x, y, r) in ((170, 620, 9), (316, 630, 10), (248, 580, 7), (130, 590, 7), (356, 596, 7)):
		s += P(B.sparkle(x, y, r), fill='#fff6fb', st=None)
	s += P('M170,470 Q240,492 310,470', st='#d94a8f', sw=7)
	return s


def lower_pepper(d, c, e, fb):
	s = P('M240,470 L240,%d' % (fb['hem'] + 6), st=OUT, sw=4)
	for side in (-1, 1):
		s += R(240 + side * 60 - 30, 556, 60, 8, rx=2, fill=darker(B.TEAL, 0.32), st=OUT, sw=3)
	# notebook sticking out of the pocket
	return s


def lower_duchess(d, c, e, fb):
	hem = fb['hem']
	shawl_end = 606
	s = fill(B.PLUM, shawl_end - 20, hem + 20)
	g = d.lin([(0, '#8552ad'), (0.5, B.PLUM), (1, '#4f2c6e')], 0, 0, 1, 0)
	s += P('M-80,%d L560,%d L560,%d L-80,%d Z' % (shawl_end - 20, shawl_end - 20, hem + 20, hem + 20), fill=g, st=None)
	for x in (90, 150, 214, 270, 330, 392):
		s += P('M%d,%d Q%d,%d %d,%d' % (240 + (x - 240) * 0.5, shawl_end, x, (shawl_end + hem) / 2, x, hem), st='#3c2158', sw=4, op=0.55)
	# shawl: its drape ends in a soft pointed edge at the hips
	drape = 'M-80,540 L560,540 L560,%d L420,%d L310,%d L240,%d L170,%d L60,%d L-80,%d Z' % (
		shawl_end, shawl_end + 12, shawl_end - 16, shawl_end + 4, shawl_end - 16, shawl_end + 12, shawl_end)
	k = d.clip('M-80,540 L560,540 L560,%d L-80,%d Z' % (shawl_end + 30, shawl_end + 30))
	s += P(drape, fill='#c4a2df', st=None, extra='') + P('M560,%d L420,%d L310,%d L240,%d L170,%d L60,%d L-80,%d' % (
		shawl_end, shawl_end + 12, shawl_end - 16, shawl_end + 4, shawl_end - 16, shawl_end + 12, shawl_end), st=OUT, sw=5)
	s += P('M184,440 L184,%d M296,440 L296,%d' % (shawl_end - 14, shawl_end - 14), st=OUT, sw=5, op=0)
	s += P('M186,430 L296,430 L300,%d L240,%d L180,%d Z' % (shawl_end - 12, shawl_end + 4, shawl_end - 12), fill=B.PLUM, st=OUT, sw=4)
	return s


def lower_bramble(d, c, e, fb):
	hem = fb['hem']
	s = P('M178,520 L302,520 L352,%d L128,%d Z' % (hem + 10, hem + 10), fill=B.OVERALL, st=OUT, sw=4.5)
	s += P('M240,532 L240,%d' % (hem + 8), st=darker(B.OVERALL, 0.35), sw=3.5)
	s += P('M178,522 L302,522', st=darker(B.OVERALL, 0.3), sw=7) + P('M156,578 Q186,590 216,578 M264,578 Q294,590 324,578', st=darker(B.OVERALL, 0.35), sw=4)
	return s


def lower_nibs(d, c, e, fb):
	hem = fb['hem']
	s = fill(B.LAB, 650, hem + 10)
	s += P('M240,600 L216,%d L264,%d Z' % (hem + 16, hem + 16), fill='#5a6068', st=None)
	s += P('M240,600 L216,%d M240,600 L264,%d' % (hem + 16, hem + 16), st=OUT, sw=4.5) + P('M240,456 L240,600', st=OUT, sw=4)
	for side in (-1, 1):
		s += R(240 + side * 84 - 34, 560, 68, 52, rx=4, fill='#e8edf2', st=OUT, sw=4)
	return s


def lower_zuzu(d, c, e, fb):
	return P('M172,560 L308,560 L324,612 L156,612 Z', fill='#25252e', st='#14141a', sw=4) + rib_hem(B.HOOD_K, 620, 660)


def lower_reginald(d, c, e, fb):
	s = P('M-80,630 L560,630', st=OUT, sw=4, op=0.55)
	return s + R(170, 620, 140, 12, rx=3, fill='#e2e2d8', st=OUT, sw=3)


def lower_grub(d, c, e, fb):
	s = fill('#fafaf6', 650, fb['hem'] + 10)
	return s + P('M112,590 Q240,612 368,590', st=OUT, sw=3, op=0.22)


def lower_marigold(d, c, e, fb):
	s = R(146, 560, 62, 56, rx=4, fill='#7fbfe0', st=OUT, sw=3.5)
	return s + P('M-80,640 L560,640', st=OUT, sw=3.5, op=0.5)


def lower_fennel(d, c, e, fb):
	hem = fb['hem']
	s = fill('#e6edf2', 650, hem + 10)
	for (x, y, r, col) in ((150, 640, 11, '#d83b3b'), (320, 620, 9, '#3a7bd5'), (290, 672, 8, '#ffd23c'), (190, 678, 7, '#4fbf6a'), (250, 600, 6, '#ff6fae')):
		s += C(x, y, r, fill=col, st=None, op=0.9)
	s += R(184, 560, 112, 60, rx=6, fill='#d7e0e7', st=OUT, sw=3.5)
	for x in (214, 266):
		s += P('M%d,562 L%d,618' % (x, x), st=OUT, sw=3, op=0.35)
	return s


def lower_sj(d, c, e, fb):
	hem = fb['hem']
	s = fill('#1d1a24', 650, hem + 12)
	s += P('M240,520 L204,%d L276,%d Z' % (hem + 16, hem + 16), fill='#2c2836', st=None)
	s += P('M240,520 L204,%d M240,520 L276,%d' % (hem + 16, hem + 16), st=OUT, sw=4.5) + P('M240,490 L240,520', st=OUT, sw=4)
	s += P('M120,640 Q180,652 214,648 M360,640 Q300,652 266,648', st='#34303e', sw=6, op=0.8)
	return s


# ---------------------------------------------------------------------------- extras drawn over the body


def over_pepper(d, c, e, fb, W):
	# notebook held in the left paw, pencil tucked in the spiral
	x, y = 240 - 156 * W, 636
	nb = R(x - 34, y - 14, 58, 66, rx=4, fill='#fbf6e4', st=OUT, sw=4.5)
	for i in range(1, 5):
		nb += P('M%s L%s' % (pt((x - 24, y - 6 + i * 11)), pt((x + 14, y - 6 + i * 11))), st='#9aa7b8', sw=2)
	nb += R(x - 34, y - 14, 10, 66, rx=2, fill='#c8423b', st=OUT, sw=3)
	return G(nb, tf=B.rot(-8, x, y)) + B.paw(x + 2, y - 4, c['fur'], 6, 25, 22)


def over_fennel(d, c, e, fb, W):
	# paint palette in the right paw
	x, y = 240 + 156 * W, 640
	pal = smooth([(x - 44, y - 6), (x - 18, y - 30), (x + 34, y - 28), (x + 54, y), (x + 30, y + 26), (x - 16, y + 24)], k=0.9)
	s = P(pal, fill='#d9a765', st=OUT, sw=5)
	for (dx, dy, col) in ((-20, -10, '#d83b3b'), (6, -16, '#3a7bd5'), (30, -8, '#ffd23c'), (24, 12, '#4fbf6a'), (-6, 12, '#ff6fae')):
		s += C(x + dx, y + dy, 7.5, fill=col, st=OUT, sw=2.5)
	return s + B.paw(x - 18, y + 10, c['fur'], -8, 22, 18)


def behind_duchess(d, c, e):
	return ''


def behind_sj(d, c, e):
	# long scaly tail curling out behind, turning to plated chrome at the tip
	green = B.taper_d((300, 610), (424, 694), (486, 590), 72, 50, 16)
	s = P(green, fill=B.SJ_G, st=OUT, sw=6)
	k = d.clip(green)
	inner = ''
	for i in range(9):
		t = i / 9.0
		px, py = B.quad_at((300, 610), (424, 788), (486, 590), t)
		inner += P('M%s Q%s %s' % (pt((px - 18, py - 8)), pt((px, py + 10)), pt((px + 18, py - 8))), st=B.SJ_GD, sw=3, op=0.65)
	s += G(inner, clip=k)
	tip = B.taper_d((466, 650), (482, 616), (486, 578), 22, 18, 4)
	s += P(tip, fill='#c4ccd5', st=OUT, sw=5)
	for (x, y) in ((472, 640), (481, 616)):
		s += P('M%s L%s' % (pt((x - 13, y)), pt((x + 13, y + 3))), st='#5d6875', sw=3)
	return s


def wisp_pants_fx(x, lw, top, end):
	return ''


def plaid_pants(x, lw, top, end):
	s = ''
	for i in range(-2, 3):
		s += R(x + i * 18 - 3, top, 6, end - top, fill='#8fb2d6', st=None)
	return s


def check_pants(x, lw, top, end):
	s = ''
	y = top
	j = 0
	while y < end:
		for i in range(-3, 4):
			if (i + j) % 2 == 0:
				s += R(x + i * 15 - 7.5, y, 15, 15, fill='#2a2a30', st=None)
		y += 15
		j += 1
	return s


def tweed_pants(x, lw, top, end):
	return ''.join(P('M%d,%d L%d,%d' % (x + i * 12, top, x + i * 12 - 8, end), st='#6c4f33', sw=2, op=0.5) for i in range(-3, 4))


def paint_pants(x, lw, top, end):
	return C(x - 10, top + 50, 7, fill='#ffd23c', st=None, op=0.9) + C(x + 12, top + 72, 6, fill='#d83b3b', st=None, op=0.9) + C(x - 4, top + 92, 5, fill='#3a7bd5', st=None, op=0.9)


# ============================================================================ per character

FULL = {
	# s: overall size; w: body width vs the bust; hem: where the top garment ends; arms: side -> down/up/bare
	'mochi': dict(s=0.96, w=0.84, hem=650, hem_w=140, pants='#c9a86a', pant_end=694, shoe='geta', foot=8, lower=lower_mochi),
	'coco': dict(s=1.06, w=0.94, hem=640, hem_w=146, pants=B.NAVY, flare=12, shoe='shoe', shoe_c='#1e1e26', ldx=62, lw=36, lower=lower_coco),
	'wisp': dict(s=1.06, w=0.86, hem=704, hem_w=196, arms={1: 'up'}, hand=(356, 414), sleeve=B.VIOLET, glove='#ffffff', pants='#231a33', ldx=48, lw=26,
		shoe='shoe', shoe_c='#15121c', shoe_c2='#c9c4d8', lower=lower_wisp),
	'bruno': dict(s=1.18, w=1.04, hem=652, hem_w=134, gy=736, top=[(78, 286), (140, 302), (180, 340)], ldx=74, lw=46, foot=14,
		pants='#cf3434', pant_end=684, shoe='boot', shoe_c='#d8343a', shoe_c2='#fff3b0', band='#d8343a', outfit=bruno_outfit_full),
	'lulu': dict(s=0.86, w=0.74, hem=668, hem_w=232, arms={-1: 'bare', 1: 'bare'}, hand_up=(1,), hand=(368, 424), gy=752, ldx=44, lw=24,
		leg='#fffaf4', shoe='mary', shoe_c='#ff6fae', foot=8, lower=lower_lulu),
	'pepper': dict(s=0.93, w=0.8, hem=652, hem_w=142, pants='#8b6a48', pants_fx=tweed_pants, shoe='shoe', shoe_c='#6b4226', lower=lower_pepper, over=over_pepper),
	'duchess': dict(s=1.05, w=0.8, hem=726, hem_w=214, gy=742, shoe='shoe', shoe_c='#b98fd8', shoe_c2='#6a3d8f', foot=2, ldx=46, lw=22, glove='#f6f0e2', lower=lower_duchess),
	'bramble': dict(s=0.98, w=0.86, hem=650, hem_w=146, arms={-1: 'up'}, hand=(112, 410), sleeve='#f6edd0', pants=B.OVERALL, shoe='rain', shoe_c='#7a5a34', lower=lower_bramble),
	'nibs': dict(s=1.0, w=0.8, hem=676, hem_w=160, pants='#5a6068', shoe='shoe', shoe_c='#4a2f20', ldx=46, lw=28, lower=lower_nibs),
	'zuzu': dict(s=0.92, w=0.8, hem=650, hem_w=140, pants='#22222a', shoe='sneaker', shoe_c='#34343f', shoe_c2=B.CYAN, lower=lower_zuzu),
	'reginald': dict(s=1.06, w=0.88, hem=640, hem_w=136, arms={1: 'up'}, hand=(392, 418), sleeve='#f8f8f2', glove='#fbfbf6', pants='#f1f1ea', pant_end=690,
		leg=B.BURGUNDY, shoe='shoe', shoe_c='#1e1e26', ldx=56, lw=30, lower=lower_reginald),
	'grub': dict(s=1.02, w=1.02, hem=652, hem_w=170, arms={-1: 'up'}, hand=(110, 414), sleeve='#fafaf6', pants='#f4f4f0', pants_fx=check_pants, shoe='clog', shoe_c='#f4f4f0', ldx=70, lw=40, foot=12, lower=lower_grub),
	'tumble': dict(s=0.8, w=0.8, hem=640, hem_w=172, gy=712, top=[(60, 300), (110, 312), (148, 342)], pants='#b9d3ec', pants_fx=plaid_pants, shoe='slipper', shoe_c='#c4553f', shoe_c2='#f4f1ea', ldx=56, lw=30),
	'marigold': dict(s=0.95, w=0.8, hem=652, hem_w=142, pants=B.SCRUB, shoe='clog', shoe_c='#f8f8f4', lower=lower_marigold),
	'fennel': dict(s=1.0, w=0.82, hem=670, hem_w=168, pants='#46506a', pants_fx=paint_pants, shoe='shoe', shoe_c='#7a4a28', ldx=50, lw=30, lower=lower_fennel, over=over_fennel),
	'snapjaw': dict(s=1.2, w=0.92, hem=672, hem_w=160, pants='#2c2836', ldx=54, lw=32, foot=12, shoe='claw', paw_c={-1: B.SJ_G, 1: '#9aa5b0'}, lower=lower_sj, behind=behind_sj),
}

for cid, ch in B.CHARS.items():
	fb = FULL[cid]
	ch['fb'] = fb
	if 'outfit' in fb:
		ch['outfit'] = fb['outfit']
	ch['neck_s'] = fb.get('neck', fb['w'])


def check(path):
	src = open(path).read()
	errs = []
	if B.FORBIDDEN.search(src):
		errs.append('forbidden: ' + B.FORBIDDEN.search(src).group(0))
	if 'width="%d" height="%d"' % (W_, H_) not in src:
		errs.append('bad header')
	if len(src) > 96 * 1024:
		errs.append('too big: %d' % len(src))
	return errs, len(src)


def main(argv):
	ids = [a for a in argv if not a.startswith('--')] or B.IDS
	os.makedirs(OUTDIR, exist_ok=True)
	bad, sizes = 0, []
	for cid in ids:
		CUR.clear()
		CUR.update(FULL[cid])
		for e in EXPRS:
			path = os.path.join(OUTDIR, '%s_%s.svg' % (cid, e))
			with open(path, 'w') as fh:
				fh.write(B.portrait(cid, e))
			errs, size = check(path)
			sizes.append(size)
			if errs:
				bad += 1
				print(path, '; '.join(errs))
	print('wrote %d full-body portraits (%d problems), %.1f KB avg, %.1f KB max' % (len(sizes), bad, sum(sizes) / 1024.0 / len(sizes), max(sizes) / 1024.0))
	return 1 if bad else 0


if __name__ == '__main__':
	sys.exit(main(sys.argv[1:]))
