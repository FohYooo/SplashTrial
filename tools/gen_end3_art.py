#!/usr/bin/env python3
"""SPLASH TRIAL - Case 3 endings art (SPOILERS: the Case 3 execution, wrong-vote ending and epilogue).

Writes, for scripts/screens/execution3_screen.gd ("STOP PRESS"):
  art/props/sp_standby       PLEASE STAND BY test card (1280x720)
  art/props/sp_newsroom      the endless newsroom, far dummies facing away (1280x720)
  art/props/sp_newsroom_turned   the same, every far dummy turned to the camera
  art/props/sp_dummy_back / sp_dummy_front   a capybara dummy reporter (220x340), from behind / facing the camera
  art/props/sp_press         the giant platen press, front view: frame and the bed (900x800)
  art/props/sp_press_front   the guide rails in front of the plate's edges (900x800, same frame)
  art/props/sp_plate         the type plate on its ram (520x900; the plate's bottom edge is y 900)
  art/props/sp_plate_under   the plate's face seen from below, slugs only (1280x720; the type is drawn in code)
  art/props/sp_straps        straps + tape over a portrait (480x600, portrait coordinates)
  art/props/sp_camera_taped  close insert: a camera taped into two paws (520x360)
  art/props/sp_paper         a newspaper sheet without words (300x400; masthead and headline are drawn in code)
  art/props/sp_booth         the control booth window, glass see-through (1280x720)
for scripts/screens/gameover3_screen.gd ("THE LINE-UP"):
  art/props/wv_wall (1280x720, tiles sideways), wv_gate (300x700), wv_placard (220x110), wv_lamp (140x200)
for scripts/screens/caiman_kill_screen.gd:
  art/props/ck_catch (680x420), ck_jaw_top (1500x560), ck_jaw_bot (1500x460), ck_cleaver (320x150), ck_toque (240x200)
and the epilogue backgrounds (scripts/data/story/story_end3.gd):
  art/bg/end3_hall, end3_hall_after   the Grand Hall at night, before and after
  art/bg/end3_terrace, end3_terrace_out   the terrace, the Gaol's cell lights across the water (one out)

Usage (from the project root):  python3 tools/gen_end3_art.py
Only SVG 1.1 basics (no text / filters / images / CSS), like every other generator. Shapes and helpers come from
tools/gen_exec2_art.py. Constants marked "shared" must stay in sync with the screens.
"""
import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from gen_exec2_art import (f, pts, svg, lin, rad, poly, path, rect, circ, ell, line, group, star_pts, blob,  # noqa: E402
	crack_path, chain_svg)

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PROPS = os.path.join(ROOT, "art", "props")
BGS = os.path.join(ROOT, "art", "bg")
TAU = math.pi * 2

BLOOD = "#7a0010"
BLOOD_D = "#3a0008"
BLOOD_H = "#b3001b"
INK = "#1a120c"
IRON = "#22262a"
IRON_M = "#3a4046"
IRON_H = "#6e777a"
PAPER = "#d8d0bc"
PAPER_S = "#b4ab94"

# ---- shared with execution3_screen.gd -----------------------------------------------------------
PRESS_W, PRESS_H = 900, 800
BED_X0, BED_X1, BED_Y0, BED_Y1 = 230, 670, 200, 700    # the bed plate between the columns (press coordinates)
PLATE_W, PLATE_H = 520, 900                           # plate sprite; its bottom edge is the crushing face
# ---- shared with gameover3_screen.gd ------------------------------------------------------------
WALL_FLOOR = 660


def write(folder, name, content):
	p = os.path.join(folder, name + ".svg")
	with open(p, "w") as fh:
		fh.write(content)
	print("wrote", os.path.relpath(p, ROOT))


def prop(name, w, h, body, defs=""):
	write(PROPS, name, svg(w, h, "\n".join(body) if isinstance(body, list) else body, defs))


def bg(name, body, defs=""):
	write(BGS, name, svg(1280, 720, "\n".join(body) if isinstance(body, list) else body, defs))


def rivets(b, x0, y0, x1, y1, step, r=4.0):
	n = max(1, int(math.hypot(x1 - x0, y1 - y0) / step))
	for i in range(n + 1):
		u = i / float(n)
		x, y = x0 + (x1 - x0) * u, y0 + (y1 - y0) * u
		b.append(circ(x, y, r + 1.4, INK))
		b.append(circ(x, y, r, IRON_M))
		b.append(circ(x - r * 0.3, y - r * 0.3, r * 0.35, IRON_H, op=0.8))


def splat(b, cx, cy, r, rng, op=1.0, drops=10, sy=1.0):
	"""A dark-red blood splat: jagged body, a darker rim, satellite drops and short spines."""
	b.append(poly(blob(cx, cy, r, rng, 22, 0.32, sy), BLOOD_D, op))
	b.append(poly(blob(cx - r * 0.06, cy - r * 0.06, r * 0.82, rng, 20, 0.28, sy), BLOOD, op))
	b.append(ell(cx - r * 0.3, cy - r * 0.3 * sy, r * 0.22, r * 0.12 * sy, BLOOD_H, op * 0.7))
	for _ in range(drops):
		a = rng.uniform(0, TAU)
		d = r * rng.uniform(1.15, 2.2)
		x, y = cx + math.cos(a) * d, cy + math.sin(a) * d * sy
		rr = rng.uniform(r * 0.04, r * 0.13)
		b.append(circ(x, y, rr, BLOOD, op))
		if rng.random() < 0.5:
			b.append(line(cx + math.cos(a) * r * 0.8, cy + math.sin(a) * r * 0.8 * sy, x, y, BLOOD, rr * 0.9, op))


# ======================================================================== STOP PRESS
def sp_standby():
	rng = random.Random(3101)
	W, H = 1280, 720
	b = [rect(0, 0, W, H, "#0b0c0b")]
	cols = ["#8c8c88", "#8c8a58", "#588a86", "#588a58", "#7e5880", "#8a5858", "#58588c"]
	bw = W / 7.0
	for i, c in enumerate(cols):
		b.append(rect(i * bw, 0, bw + 1, 410, c))
	for i in range(8):
		v = int(14 + i * 29)
		b.append(rect(i * W / 8.0, 410, W / 8.0 + 1, 64, "#%02x%02x%02x" % (v, v, v)))
	for i, c in enumerate(["#1e2a36", "#d6d6d2", "#2a1e36", "#0b0c0b", "#060606", "#0b0c0b", "#151515"]):
		b.append(rect(i * bw, 474, bw + 1, 246, c))
	b.append(rect(0, 0, W, H, "#000000", op=0.38))
	for _ in range(44):
		b.append(poly(blob(rng.uniform(0, W), rng.uniform(0, H), rng.uniform(20, 90), rng, 12, 0.5, 0.6), "#000000", op=rng.uniform(0.08, 0.26)))
	# the leader circle: a newsreel countdown ring around a printing roller and a fedora with a press card
	b.append(circ(640, 300, 214, "#0e0f10", op=0.92))
	b.append(circ(640, 300, 214, "none", stroke="#c8c8c4", sw=6, op=0.8))
	b.append(circ(640, 300, 172, "none", stroke="#c8c8c4", sw=2, op=0.35))
	b.append(line(426, 300, 854, 300, "#c8c8c4", 3, 0.4))
	b.append(line(640, 86, 640, 514, "#c8c8c4", 3, 0.4))
	# the roller (a long cylinder with type ribs)
	b.append(rect(500, 330, 280, 64, "#2e2e30", rx=30, stroke="#a8a8a2", sw=4))
	for i in range(9):
		x = 524 + i * 29
		b.append(line(x, 336, x, 388, "#8a8a86", 3, 0.6))
	b.append(ell(500, 362, 16, 32, "#4a4a4c", stroke="#a8a8a2", sw=4))
	b.append(ell(780, 362, 16, 32, "#4a4a4c", stroke="#a8a8a2", sw=4))
	# the fedora, with a small card in the band
	b.append(ell(640, 300, 150, 26, "#2a2a2c", stroke="#a8a8a2", sw=4))
	b.append(path("M548 296 Q552 200 640 196 Q728 200 732 296 Z", "#323234", stroke="#a8a8a2", sw=4))
	b.append(path("M600 206 Q640 230 680 206", stroke="#a8a8a2", sw=3, op=0.7))
	b.append(rect(552, 262, 176, 22, "#1a1a1c"))
	b.append(rect(664, 236, 50, 34, "#d6d6cc", tr="rotate(-8 689 253)"))
	b.append(rect(672, 246, 32, 4, "#3a3a3a", tr="rotate(-8 689 253)"))
	b.append(rect(672, 256, 22, 4, "#3a3a3a", tr="rotate(-8 689 253)"))
	prop("sp_standby", W, H, b)


def _desk(b, x, y, s, rng, flip=False):
	"""A newsroom desk with a typewriter and a green-shaded lamp (front-ish view), base centre at (x, y)."""
	w = 150 * s
	h = 52 * s
	b.append(rect(x - w * 0.5, y - h, w, h * 0.28, "#3a2a1c"))
	b.append(rect(x - w * 0.5, y - h * 0.72, w, h * 0.72, "#24190f"))
	b.append(rect(x - w * 0.46, y - h * 0.6, w * 0.08, h * 0.6, "#1a120b"))
	b.append(rect(x + w * 0.38, y - h * 0.6, w * 0.08, h * 0.6, "#1a120b"))
	# typewriter
	tx = x + (-w * 0.12 if not flip else w * 0.12)
	b.append(path("M%s %s L%s %s L%s %s L%s %s Z" % (f(tx - 26 * s), f(y - h), f(tx + 26 * s), f(y - h), f(tx + 20 * s), f(y - h - 16 * s),
		f(tx - 20 * s), f(y - h - 16 * s)), "#141414"))
	b.append(rect(tx - 22 * s, y - h - 24 * s, 44 * s, 8 * s, "#1c1c1c", rx=3 * s))
	b.append(rect(tx - 12 * s, y - h - 34 * s, 24 * s, 12 * s, PAPER_S, op=0.8))
	# lamp
	lx = x + (w * 0.32 if not flip else -w * 0.32)
	b.append(line(lx, y - h, lx, y - h - 22 * s, "#5a4a2a", 2.4 * s))
	b.append(path("M%s %s Q%s %s %s %s Z" % (f(lx - 14 * s), f(y - h - 20 * s), f(lx), f(y - h - 34 * s), f(lx + 14 * s), f(y - h - 20 * s)), "#1f5a3a"))
	b.append(ell(lx, y - h - 16 * s, 26 * s, 10 * s, "#e0c070", op=0.22))
	b.append(ell(lx, y - h + 2 * s, 40 * s, 7 * s, "#e0c070", op=0.14))


def _far_dummy(b, x, y, s, turned):
	"""A tiny dummy reporter seated at a desk, seen from behind or turned to the camera."""
	head = "#b7aa94" if turned else "#9c907c"
	b.append(path("M%s %s Q%s %s %s %s L%s %s Z" % (f(x - 22 * s), f(y), f(x - 20 * s), f(y - 40 * s), f(x), f(y - 42 * s), f(x + 22 * s), f(y)), "#2c2a28"))
	b.append(path("M%s %s Q%s %s %s %s Z" % (f(x), f(y - 42 * s), f(x + 20 * s), f(y - 40 * s), f(x + 22 * s), f(y)), "#2c2a28"))
	b.append(ell(x, y - 54 * s, 15 * s, 14 * s, head))
	b.append(circ(x - 10 * s, y - 66 * s, 4 * s, head))
	b.append(circ(x + 10 * s, y - 66 * s, 4 * s, head))
	if turned:
		b.append(ell(x, y - 46 * s, 10 * s, 7 * s, "#cfc4ae"))
		b.append(circ(x - 5 * s, y - 58 * s, 1.6 * s, "#1a1410", op=0.8))
		b.append(circ(x + 5 * s, y - 58 * s, 1.6 * s, "#1a1410", op=0.8))
	b.append(ell(x, y - 66 * s, 17 * s, 4 * s, "#1e1e20"))
	b.append(rect(x - 10 * s, y - 80 * s, 20 * s, 14 * s, "#262628", rx=4 * s))


def _newsroom(turned):
	rng = random.Random(3102)
	W, H = 1280, 720
	VX, VY = 640, 236
	defs = (lin("nrwall", 0, 0, 0, 1, [(0, "#0b0d0d"), (0.55, "#1a1f1d"), (1, "#0d100f")])
		+ lin("nrfloor", 0, 0, 0, 1, [(0, "#14100c"), (1, "#2a2017")])
		+ rad("lamp", 0.5, 0.5, 0.5, [(0, "#f2d79a", 0.55), (0.5, "#c8a060", 0.16), (1, "#000000", 0)])
		+ lin("cone", 0, 0, 0, 1, [(0, "#f0d8a0", 0.32), (1, "#f0d8a0", 0)]))
	b = [rect(0, 0, W, H, "url(#nrwall)")]
	# ceiling and floor planes
	b.append(poly([(0, 0), (W, 0), (VX + 70, VY - 46), (VX - 70, VY - 46)], "#090a0a"))
	b.append(poly([(0, H), (W, H), (VX + 60, VY + 40), (VX - 60, VY + 40)], "url(#nrfloor)"))
	for i in range(-16, 17):
		x = VX + i * 90
		b.append(line(VX + i * 4, VY + 40, x, H, "#0e0a07", 2, 0.7))
	for k in range(1, 14):
		u = (k / 14.0) ** 1.9
		y = VY + 40 + (H - VY - 40) * u
		b.append(line(0, y, W, y, "#0e0a07", 1.5, 0.45))
	# side walls with windows (blinds) receding
	for side in (-1, 1):
		for k in range(7):
			d = 0.12 + k * 0.13
			x0 = VX + side * (640 - 560 * d)
			x1 = VX + side * (640 - 560 * (d + 0.08))
			y0t, y0b = 60 + (VY - 100) * d, 500 - (500 - VY) * d
			y1t, y1b = 60 + (VY - 100) * (d + 0.08), 500 - (500 - VY) * (d + 0.08)
			b.append(poly([(x0, y0t), (x1, y1t), (x1, y1b), (x0, y0b)], "#1c2a2c", 0.8))
			for j in range(8):
				v = j / 8.0
				b.append(line(x0, y0t + (y0b - y0t) * v, x1, y1t + (y1b - y1t) * v, "#2c3c3e", 2, 0.7))
	# pillars at depth
	for k in range(6):
		d = 0.05 + k * 0.16
		s = 1.0 - d * 0.92
		for side in (-1, 1):
			x = VX + side * (520 * s + 40)
			top = VY - 46 - (VY - 46) * s
			bot = VY + 40 + (H - VY - 40) * s
			b.append(rect(x - 24 * s, top, 48 * s, bot - top, "#151816"))
			b.append(rect(x - 24 * s, top, 8 * s, bot - top, "#232825", op=0.8))
	# hanging lamps, cones of light
	for k in range(7):
		d = k / 7.0
		s = 1.0 - d * 0.9
		for side in (-1, 1):
			x = VX + side * 300 * s
			y = VY - 46 - (VY - 46) * s * 0.55
			b.append(line(x, y - 120 * s, x, y, "#050505", 2))
			b.append(poly([(x - 30 * s, y + 6 * s), (x + 30 * s, y + 6 * s), (x + 180 * s, y + 420 * s), (x - 180 * s, y + 420 * s)], "url(#cone)", 0.35))
			b.append(path("M%s %s Q%s %s %s %s Z" % (f(x - 24 * s), f(y + 8 * s), f(x), f(y - 18 * s), f(x + 24 * s), f(y + 8 * s)), "#1e3a2c"))
			b.append(circ(x, y + 6 * s, 40 * s, "url(#lamp)"))
	# the far dais where the press stands (the press itself is a sprite)
	b.append(poly([(VX - 210, VY + 64), (VX + 210, VY + 64), (VX + 250, VY + 92), (VX - 250, VY + 92)], "#20160e"))
	b.append(rect(VX - 250, VY + 92, 500, 16, "#120c08"))
	b.append(circ(VX, VY - 10, 230, "url(#lamp)", op=0.55))
	# rows of desks with dummies, back to front (the near rows are sprites)
	for k in range(9, 0, -1):
		d = k / 10.0
		s = 0.2 + (1.0 - d) * 0.55
		y = VY + 60 + (H - VY - 60) * (1.0 - d) ** 1.6 * 0.62
		for side in (-1, 1):
			for j in range(3):
				x = VX + side * (110 + j * 150) * s * 1.6
				if abs(x - VX) < 80 * s * 1.6:
					continue
				_far_dummy(b, x, y - 42 * s, s, turned)
				_desk(b, x, y, s, rng, side > 0)
	b.append(rect(0, 0, W, H, "#000000", op=0.12))
	prop("sp_newsroom_turned" if turned else "sp_newsroom", W, H, b, defs)


def _dummy(front):
	W, H = 220, 340
	skin = "#cbbda4"
	skin_s = "#a8987c"
	coat = "#3a3631"
	coat_s = "#28251f"
	b = []
	# trench coat shoulders and collar
	b.append(path("M14 340 Q18 236 70 214 L150 214 Q202 236 206 340 Z", coat, stroke=INK, sw=4))
	if front:
		b.append(path("M84 216 L110 300 L136 216 Z", "#dcd6c8", stroke=INK, sw=3))
		b.append(path("M110 238 L104 300 L110 318 L116 300 Z", "#4a1a1a", stroke=INK, sw=2))
		b.append(path("M70 214 L100 300 L60 340 Z", coat_s, op=0.8))
		b.append(path("M150 214 L120 300 L160 340 Z", coat_s, op=0.8))
		# a press camera held at the chest, with a big flash dish
		b.append(rect(66, 272, 88, 54, "#1a1a1c", rx=6, stroke=INK, sw=3))
		b.append(circ(110, 300, 18, "#2a3036", stroke="#8a9096", sw=3))
		b.append(circ(106, 296, 5, "#ffffff", op=0.6))
		b.append(line(150, 276, 176, 236, "#555a60", 4))
		b.append(circ(184, 222, 28, "#b8bec4", stroke=INK, sw=3))
		b.append(circ(184, 222, 18, "#e8ecef"))
		b.append(circ(184, 222, 7, "#ffffff"))
	else:
		b.append(path("M110 214 L110 340", stroke=coat_s, sw=4))
		b.append(path("M60 240 Q110 262 160 240", stroke=coat_s, sw=5))
		b.append(line(56, 230, 170, 320, "#151515", 4, 0.8))
	# the head: a blank capybara dummy, boxy, small round ears, big blunt snout - no eyes, no mouth
	b.append(path("M58 214 L58 120 Q60 70 110 66 Q160 70 162 120 L162 214 Z", skin, stroke=INK, sw=4))
	b.append(circ(68, 74, 13, skin, stroke=INK, sw=4))
	b.append(circ(152, 74, 13, skin, stroke=INK, sw=4))
	if front:
		b.append(path("M70 150 Q70 128 110 126 Q150 128 150 150 L150 196 Q150 214 110 214 Q70 214 70 196 Z", "#d6c9b0", stroke=INK, sw=3))
		b.append(line(110, 66, 110, 214, skin_s, 1.6, 0.8))
		b.append(ell(86, 108, 6, 4, "#5e5040", op=0.55))
		b.append(ell(134, 108, 6, 4, "#5e5040", op=0.55))
	else:
		b.append(path("M70 120 Q110 100 150 120", stroke=skin_s, sw=3, op=0.6))
		b.append(line(110, 70, 110, 214, skin_s, 2, 0.7))
	b.append(path("M58 120 Q60 70 110 66 L110 214 L58 214 Z", "#000000", op=0.12))
	# the fedora, a card in the band
	b.append(ell(110, 72, 74, 16, "#28282a", stroke=INK, sw=4))
	b.append(path("M62 70 Q64 20 110 18 Q156 20 158 70 Z", "#303032", stroke=INK, sw=4))
	b.append(rect(64, 54, 92, 12, "#151517"))
	if front:
		b.append(rect(122, 40, 30, 22, "#dcd6c8", tr="rotate(-8 137 51)"))
		b.append(rect(126, 46, 20, 3, "#3a3a3a", tr="rotate(-8 137 51)"))
	else:
		b.append(rect(70, 40, 28, 20, "#c4beb0", op=0.85, tr="rotate(6 84 50)"))
	prop("sp_dummy_front" if front else "sp_dummy_back", W, H, b)


def sp_press():
	W, H = PRESS_W, PRESS_H
	defs = (lin("iron", 0, 0, 1, 0, [(0, "#1a1d20"), (0.35, "#3a4148"), (0.6, "#2a2f34"), (1, "#121416")])
		+ lin("bed", 0, 0, 0, 1, [(0, "#2a2e32"), (1, "#16181a")])
		+ lin("brass", 0, 0, 0, 1, [(0, "#b8964a"), (1, "#6a5228")]))
	b = []
	# base
	b.append(rect(30, 700, 840, 100, "#15171a", stroke=INK, sw=5))
	b.append(rect(30, 700, 840, 14, "#3a4046"))
	rivets(b, 60, 760, 840, 760, 60, 5)
	# columns
	for x0 in (70, 700):
		b.append(rect(x0, 120, 130, 590, "url(#iron)", stroke=INK, sw=6))
		b.append(rect(x0 + 18, 150, 16, 540, "#5a636a", op=0.35))
		rivets(b, x0 + 100, 170, x0 + 100, 680, 64, 5)
		b.append(path("M%d 120 L%d 90 L%d 90 L%d 120 Z" % (x0, x0 + 20, x0 + 110, x0 + 130), "#2a2f34", stroke=INK, sw=5))
	# crosshead with the ram housing and gears
	b.append(rect(30, 40, 840, 110, "url(#iron)", stroke=INK, sw=6))
	b.append(rect(30, 40, 840, 16, "#4a5258"))
	rivets(b, 70, 128, 830, 128, 52, 5)
	b.append(rect(370, 20, 160, 150, "#2a2f34", stroke=INK, sw=6))
	b.append(ell(450, 150, 70, 18, "#0c0d0e"))
	for cx, cy, r, n in ((180, 60, 70, 14), (290, 40, 44, 10), (760, 70, 60, 12)):
		d = ""
		for i in range(n * 2):
			a = TAU * i / (n * 2)
			rr = r if i % 2 == 0 else r * 0.84
			d += ("M" if i == 0 else "L") + "%s %s " % (f(cx + math.cos(a) * rr), f(cy + math.sin(a) * rr))
		b.append(path(d + "Z", "#2e3338", stroke=INK, sw=4))
		b.append(circ(cx, cy, r * 0.35, "#14171a", stroke="#5a636a", sw=3))
	# the bed: a riveted iron plate, a paper tray at its foot
	b.append(rect(BED_X0, BED_Y0, BED_X1 - BED_X0, BED_Y1 - BED_Y0, "url(#bed)", stroke=INK, sw=6))
	b.append(rect(BED_X0 + 14, BED_Y0 + 14, BED_X1 - BED_X0 - 28, BED_Y1 - BED_Y0 - 28, "none", stroke="#454c52", sw=3, op=0.7))
	rivets(b, BED_X0 + 30, BED_Y0 + 30, BED_X1 - 30, BED_Y0 + 30, 48, 4)
	rivets(b, BED_X0 + 30, BED_Y0 + 30, BED_X0 + 30, BED_Y1 - 30, 48, 4)
	rivets(b, BED_X1 - 30, BED_Y0 + 30, BED_X1 - 30, BED_Y1 - 30, 48, 4)
	for i in range(6):
		b.append(line(BED_X0 + 60 + i * 64, BED_Y0 + 40, BED_X0 + 40 + i * 64, BED_Y1 - 40, "#000000", 2, 0.18))
	b.append(rect(BED_X0 - 30, BED_Y1 - 6, BED_X1 - BED_X0 + 60, 24, "#2a2f34", stroke=INK, sw=4))
	for i in range(5):
		b.append(rect(BED_X0 - 14 + i * 3, BED_Y1 - 12 - i * 3, BED_X1 - BED_X0 + 30, 4, PAPER, op=0.85))
	# a pressure gauge on the left column
	b.append(circ(135, 250, 38, "#d8d0bc", stroke=INK, sw=6))
	b.append(circ(135, 250, 30, "none", stroke="#7a0010", sw=6, op=0.6))
	b.append(line(135, 250, 156, 230, INK, 4))
	b.append(rect(118, 288, 34, 30, "url(#brass)", stroke=INK, sw=3))
	b.append(rect(0, 0, W, H, "#000000", op=0.05))
	prop("sp_press", W, H, b, defs)


def sp_press_front():
	W, H = PRESS_W, PRESS_H
	b = []
	# guide rails just inside the columns; the plate's edges slide behind them
	for x0 in (196, 674):
		b.append(rect(x0, 150, 30, 560, "#2c3237", stroke=INK, sw=5))
		b.append(rect(x0 + 6, 160, 6, 540, "#6e777a", op=0.5))
		rivets(b, x0 + 15, 190, x0 + 15, 680, 80, 4)
	prop("sp_press_front", W, H, b)


def sp_plate():
	W, H = PLATE_W, PLATE_H
	defs = (lin("ram", 0, 0, 1, 0, [(0, "#1a1d20"), (0.4, "#5a636a"), (1, "#15171a")])
		+ lin("plate", 0, 0, 0, 1, [(0, "#3a4046"), (0.6, "#24282c"), (1, "#14161a")]))
	b = []
	# the threaded ram
	b.append(rect(214, 0, 92, 610, "url(#ram)", stroke=INK, sw=5))
	for y in range(8, 600, 22):
		b.append(line(216, y, 304, y + 9, "#0c0d0e", 4, 0.7))
		b.append(line(216, y + 3, 304, y + 12, "#7a838a", 1.5, 0.4))
	b.append(rect(170, 580, 180, 40, "#2a2f34", stroke=INK, sw=5))
	# the plate block
	b.append(rect(4, 610, 512, 262, "url(#plate)", stroke=INK, sw=6))
	b.append(rect(22, 628, 476, 226, "none", stroke="#5a636a", sw=4, op=0.6))
	rivets(b, 40, 646, 480, 646, 55, 6)
	rivets(b, 40, 836, 480, 836, 55, 6)
	for i in range(5):
		b.append(line(60 + i * 100, 660, 40 + i * 100, 820, "#000000", 3, 0.2))
	# the type slugs along the bottom face
	b.append(rect(10, 868, 500, 22, "#121416", stroke=INK, sw=4))
	x = 16
	rng = random.Random(3103)
	while x < 500:
		w = rng.choice([10, 14, 18, 22, 8])
		b.append(rect(x, 886, w, 12, "#8a9298", stroke=INK, sw=2))
		x += w + rng.choice([3, 4, 8])
	prop("sp_plate", W, H, b, defs)


def sp_plate_under():
	"""The face of the plate seen from below: an iron chase full of type slugs, rushing at the lens."""
	W, H = 1280, 720
	defs = rad("pu_light", 0.5, 0.45, 0.65, [(0, "#4a5258"), (1, "#0e1012")])
	b = [rect(0, 0, W, H, "url(#pu_light)")]
	b.append(rect(40, 40, 1200, 640, "none", stroke="#0a0b0c", sw=40))
	b.append(rect(60, 60, 1160, 600, "none", stroke="#6e777a", sw=4, op=0.5))
	rng = random.Random(3104)
	for row in range(9):
		y = 92 + row * 64
		x = 90
		while x < 1180:
			w = rng.choice([22, 30, 38, 44, 18, 52])
			b.append(rect(x, y, w, 50, "#2a2f34", stroke="#0a0b0c", sw=3))
			b.append(rect(x + 3, y + 3, w - 6, 6, "#7a838a", op=0.35))
			x += w + 4
	rivets(b, 70, 70, 1210, 70, 140, 8)
	rivets(b, 70, 650, 1210, 650, 140, 8)
	prop("sp_plate_under", W, H, b, defs)


def sp_straps():
	W, H = 480, 600
	defs = lin("leather", 0, 0, 0, 1, [(0, "#5a3a22"), (0.5, "#43281a"), (1, "#2c1a10")]) + lin("tape", 0, 0, 0, 1, [(0, "#c8cccc"), (1, "#8a9094")])
	b = []
	for y, tilt in ((468, -3), (548, 2)):
		tr = "rotate(%d 240 %d)" % (tilt, y)
		b.append(rect(-20, y - 20, 520, 40, "url(#leather)", stroke=INK, sw=4, tr=tr))
		b.append(rect(-20, y - 14, 520, 3, "#7a5638", op=0.6, tr=tr))
		for x in range(10, 480, 34):
			b.append(rect(x, y + 10, 10, 3, "#1a0f08", op=0.6, tr=tr))
		b.append(rect(150, y - 26, 44, 52, "none", stroke="#c0a050", sw=7, tr=tr))
		b.append(line(172, y - 22, 172, y + 22, "#c0a050", 5))
	# silver tape wound round the camera on her chest (lens at about 298, 412)
	for (x0, y0, x1, y1) in ((246, 380, 352, 444), (246, 444, 352, 380), (236, 412, 362, 412)):
		ang = math.degrees(math.atan2(y1 - y0, x1 - x0))
		ln = math.hypot(x1 - x0, y1 - y0)
		cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
		tr = "rotate(%s %s %s)" % (f(ang), f(cx), f(cy))
		b.append(rect(cx - ln / 2, cy - 9, ln, 18, "url(#tape)", stroke="#4a5054", sw=2, tr=tr, op=0.95))
		b.append(rect(cx - ln / 2, cy - 6, ln, 2, "#ffffff", tr=tr, op=0.45))
	prop("sp_straps", W, H, b, defs)


def sp_camera_taped():
	"""Close insert: her camera, held up in both paws, and the tape wound round paws and camera together."""
	W, H = 520, 360
	defs = (lin("cam", 0, 0, 0, 1, [(0, "#3a3a3e"), (1, "#141416")])
		+ lin("plate2", 0, 0, 0, 1, [(0, "#d8dcde"), (1, "#8a9094")])
		+ rad("lens2", 0.4, 0.35, 0.7, [(0, "#6a9ad0"), (0.5, "#1c3456"), (1, "#05080e")]))
	fur, fur_s, pad = "#a07a50", "#74563a", "#5a4030"
	tape, tape_s = "#c4c8c6", "#8e9492"
	b = []
	# the camera: black body, silver top plate, a winder, a big lens, the red record light
	b.append(rect(120, 104, 280, 176, "url(#cam)", rx=14, stroke=INK, sw=6))
	b.append(rect(120, 104, 280, 40, "url(#plate2)", rx=10, stroke=INK, sw=5))
	b.append(rect(180, 80, 64, 30, "#2a2a2e", stroke=INK, sw=4))
	b.append(rect(330, 90, 36, 18, "#c8ccce", stroke=INK, sw=3))
	for k in range(7):
		b.append(line(126 + k * 40, 150, 126 + k * 40, 274, "#000000", 2, 0.25))
	b.append(circ(260, 206, 78, "#0c0c0e", stroke=INK, sw=6))
	b.append(circ(260, 206, 62, "#3a3e42", stroke="#6a6e72", sw=4))
	b.append(circ(260, 206, 46, "url(#lens2)", stroke="#1a1e22", sw=4))
	b.append(circ(242, 188, 13, "#ffffff", op=0.55))
	b.append(circ(282, 228, 5, "#ffffff", op=0.3))
	b.append(circ(372, 136, 8, "#ff2a2a", stroke=INK, sw=2))
	# two paws gripping it from the sides, fingers curled over the body
	for side in (-1, 1):
		cx = 260 + side * 178
		b.append(path("M%s 360 Q%s 280 %s 220 Q%s 150 %s 140 Q%s 150 %s 214 L%s 360 Z" % (
			f(cx - 64 * side), f(cx - 70 * side), f(cx - 52 * side), f(cx - 30 * side), f(cx + 16 * side),
			f(cx + 56 * side), f(cx + 62 * side), f(cx + 78 * side)), fur, stroke=INK, sw=6))
		b.append(path("M%s 360 Q%s 290 %s 230" % (f(cx + 36 * side), f(cx + 42 * side), f(cx + 30 * side)), stroke=fur_s, sw=9, op=0.6))
		for k in range(3):
			y = 162 + k * 30
			fx = cx - 40 * side
			b.append(path("M%s %s Q%s %s %s %s Q%s %s %s %s Z" % (f(fx), f(y), f(fx - 34 * side), f(y - 4), f(fx - 44 * side), f(y + 12),
				f(fx - 34 * side), f(y + 26), f(fx), f(y + 22)), fur, stroke=INK, sw=4))
			b.append(path("M%s %s L%s %s L%s %s Z" % (f(fx - 42 * side), f(y + 6), f(fx - 54 * side), f(y + 12), f(fx - 42 * side), f(y + 18)),
				"#efe4cc", stroke=INK, sw=2))
		b.append(ell(cx + 6 * side, 300, 22, 16, pad, op=0.5))
	# grey tape, flat and dull, three turns: round each paw and across the top, binding paws to camera
	def strip(x0, y0, x1, y1, w=26):
		ang = math.degrees(math.atan2(y1 - y0, x1 - x0))
		ln = math.hypot(x1 - x0, y1 - y0)
		cx2, cy2 = (x0 + x1) / 2, (y0 + y1) / 2
		tr = "rotate(%s %s %s)" % (f(ang), f(cx2), f(cy2))
		b.append(rect(cx2 - ln / 2, cy2 - w / 2, ln, w, tape, stroke=tape_s, sw=2, tr=tr, op=0.96))
		b.append(rect(cx2 - ln / 2, cy2 - w / 2 + 4, ln, 3, "#e8ecea", tr=tr, op=0.6))
		for k in range(int(ln / 22)):
			b.append(line(cx2 - ln / 2 + 10 + k * 22, cy2 - w / 2 + 2, cx2 - ln / 2 + 14 + k * 22, cy2 + w / 2 - 2, tape_s, 1.2, 0.5).replace(
				"/>", ' transform="%s"/>' % tr))
	strip(40, 196, 190, 176)
	strip(330, 176, 480, 196)
	strip(60, 120, 460, 120, 30)
	strip(70, 262, 180, 250, 22)
	strip(340, 250, 450, 262, 22)
	prop("sp_camera_taped", W, H, b, defs)


def sp_paper():
	W, H = 300, 400
	defs = lin("pp", 0, 0, 1, 1, [(0, "#e2dac6"), (0.7, PAPER), (1, PAPER_S)])
	b = [rect(0, 0, W, H, "url(#pp)", stroke="#8a826c", sw=2)]
	b.append(rect(12, 12, 276, 46, "#1c1a18"))
	b.append(line(12, 64, 288, 64, "#2a2620", 2))
	b.append(line(12, 68, 288, 68, "#2a2620", 1))
	# headline space stays blank (y 74 to 148): the screen prints the words there
	b.append(line(12, 152, 288, 152, "#2a2620", 1.5))
	rng = random.Random(3106)
	# a photograph box: a camera on a bare floor
	b.append(rect(16, 162, 128, 92, "#4a4640"))
	b.append(rect(16, 162, 128, 92, "none", stroke="#2a2620", sw=2))
	b.append(rect(52, 214, 52, 30, "#1a1816"))
	b.append(circ(78, 229, 10, "#6a665e"))
	for col, (x0, x1) in enumerate(((152, 284), (16, 96), (106, 192), (202, 284))):
		y0, y1 = (166, 254) if col == 0 else (264, 384)
		y = y0
		while y < y1:
			x_end = x1 - rng.uniform(0, 14) if rng.random() < 0.85 else x0 + (x1 - x0) * rng.uniform(0.3, 0.7)
			b.append(line(x0, y, x_end, y, "#6a6458", 3, 0.75))
			y += 9
	b.append(line(100, 260, 100, 386, "#8a826c", 1))
	b.append(line(197, 260, 197, 386, "#8a826c", 1))
	b.append(path("M0 0 L300 0 L300 18 Q150 6 0 22 Z", "#ffffff", op=0.12))
	prop("sp_paper", W, H, b, defs)


def sp_booth():
	W, H = 1280, 720
	defs = (lin("frame", 0, 0, 0, 1, [(0, "#2a2f34"), (1, "#121416")])
		+ lin("desk", 0, 0, 0, 1, [(0, "#2a241e"), (1, "#0e0b08")]))
	b = []
	# the wall around the window (the glass area stays empty: the screen draws what's behind it)
	b.append(path("M0 0 L1280 0 L1280 720 L0 720 Z M150 96 L150 548 L1130 548 L1130 96 Z", "#101214"))
	b.append(rect(130, 76, 1020, 492, "none", stroke="url(#frame)", sw=40))
	b.append(rect(150, 96, 980, 452, "none", stroke="#5a636a", sw=3, op=0.6))
	b.append(line(640, 96, 640, 548, "#22262a", 18))
	rivets(b, 130, 64, 1150, 64, 85, 6)
	# reflections on the glass
	for (x0, w, op) in ((260, 90, 0.07), (380, 26, 0.09), (820, 140, 0.05), (1000, 30, 0.08)):
		b.append(poly([(x0, 96), (x0 + w, 96), (x0 + w - 230, 548), (x0 - 230, 548)], "#ffffff", op))
	b.append(path("M300 470 Q340 440 380 476 Q350 500 300 470 Z", "#ffffff", op=0.04))
	# the control desk below the window
	b.append(rect(0, 568, 1280, 152, "url(#desk)"))
	b.append(rect(0, 568, 1280, 10, "#3a3026"))
	for x in (240, 380, 900, 1040):
		b.append(circ(x, 630, 34, "#d8d0bc", stroke=INK, sw=6))
		b.append(circ(x, 630, 26, "none", stroke=BLOOD, sw=5, op=0.5))
		b.append(line(x, 630, x + 18, 612, INK, 4))
	# the big lever (the screen pulls it)
	b.append(rect(600, 600, 80, 50, "#2a2f34", stroke=INK, sw=5))
	# the ON AIR box, top centre (dark; the screen lights it)
	b.append(rect(565, 18, 150, 46, "#2a0004", stroke=INK, sw=4))
	prop("sp_booth", W, H, b, defs)


# ======================================================================== THE LINE-UP
def wv_wall():
	W, H = 1280, 720
	rng = random.Random(3201)
	defs = lin("wall", 0, 0, 0, 1, [(0, "#2c322f"), (0.6, "#3a423e"), (1, "#2a302d")])
	b = [rect(0, 0, W, H, "url(#wall)")]
	for _ in range(60):
		x, y = rng.uniform(80, W - 80), rng.uniform(80, WALL_FLOOR - 40)
		b.append(poly(blob(x, y, rng.uniform(20, 70), rng, 12, 0.45, 0.7), rng.choice(["#262b28", "#434c47"]), op=rng.uniform(0.15, 0.4)))
	# the height chart: a line every 60 px, a heavy one every 120
	for i, y in enumerate(range(120, WALL_FLOOR, 60)):
		heavy = i % 2 == 0
		b.append(line(0, y, W, y, "#c8ccc4", 5 if heavy else 2.5, 0.7 if heavy else 0.45))
		for x in range(0, W, 40):
			b.append(line(x, y - 8, x, y, "#c8ccc4", 2, 0.3))
	# grime running down from the lines
	for _ in range(30):
		x = rng.uniform(20, W - 20)
		y = rng.choice(range(120, WALL_FLOOR, 60))
		b.append(line(x, y, x + rng.uniform(-3, 3), y + rng.uniform(20, 60), "#1e2220", rng.uniform(2, 5), 0.35))
	# the ceiling band and a pipe
	b.append(rect(0, 0, W, 64, "#121514"))
	b.append(rect(0, 46, W, 16, "#2a2f2c", stroke=INK, sw=3))
	for x in range(0, W, 160):
		b.append(rect(x + 70, 40, 18, 28, "#1a1e1c", stroke=INK, sw=2))
	# floor
	b.append(rect(0, WALL_FLOOR, W, H - WALL_FLOOR, "#1a1e1c"))
	b.append(rect(0, WALL_FLOOR, W, 8, "#0c0e0d"))
	for x in range(0, W, 128):
		b.append(line(x, WALL_FLOOR + 8, x - 40, H, "#0f1211", 2, 0.6))
	for x0 in (320, 960):
		b.append(rect(x0 - 60, 684, 120, 22, "#0a0b0b", stroke="#3a403c", sw=3))
		for k in range(7):
			b.append(line(x0 - 52 + k * 17, 686, x0 - 52 + k * 17, 704, "#3a403c", 3))
	prop("wv_wall", W, H, b, defs)


def wv_gate():
	W, H = 300, 700
	defs = lin("bar", 0, 0, 1, 0, [(0, "#1a1d1f"), (0.45, "#4a5054"), (1, "#141618")])
	b = []
	b.append(rect(6, 10, 288, 34, "#2a2f32", stroke=INK, sw=5))
	rivets(b, 24, 27, 276, 27, 42, 5)
	for i in range(5):
		x = 30 + i * 60
		b.append(rect(x - 11, 40, 22, 600, "url(#bar)", stroke=INK, sw=4))
		b.append(poly([(x - 13, 636), (x + 13, 636), (x, 700)], "#3a4044", stroke=INK, sw=4))
		b.append(line(x - 4, 640, x, 690, "#8a9296", 2, 0.6))
		# rust
		b.append(line(x + 4, 120 + i * 37, x + 4, 180 + i * 37, "#5a2a14", 4, 0.5))
	for y in (180, 380, 560):
		b.append(rect(8, y - 12, 284, 24, "url(#bar)", stroke=INK, sw=4))
		rivets(b, 30, y, 270, y, 60, 4)
	prop("wv_gate", W, H, b, defs)


def wv_placard():
	W, H = 220, 110
	b = [rect(4, 4, 212, 102, "#141414", rx=4, stroke="#d8d8d0", sw=5)]
	b.append(rect(14, 14, 192, 82, "none", stroke="#d8d8d0", sw=1.5, op=0.6))
	b.append(circ(30, 18, 4, "#d8d8d0"))
	b.append(circ(190, 18, 4, "#d8d8d0"))
	prop("wv_placard", W, H, b)


def wv_lamp():
	W, H = 140, 200
	b = [line(70, 0, 70, 70, "#0a0a0a", 4)]
	b.append(path("M30 110 L50 70 L90 70 L110 110 Z", "#2a2f2c", stroke=INK, sw=4))
	b.append(ell(70, 110, 40, 8, "#141614", stroke=INK, sw=3))
	b.append(ell(70, 132, 18, 22, "#f4ead0", op=0.95))
	for k in range(5):
		x = 50 + k * 10
		b.append(line(x, 112, x + (70 - x) * 0.2, 160, "#1a1c1a", 3))
	b.append(ell(70, 160, 14, 4, "#1a1c1a"))
	prop("wv_lamp", W, H, b)


# ======================================================================== CAIMAN'S KILL
def ck_catch():
	"""Snapjaw's claw closing round a furry wrist in a white sleeve; the cleaver stopped dead."""
	W, H = 680, 420
	defs = (lin("blade", 0, 0, 0, 1, [(0, "#d8dee2"), (0.5, "#9aa2a8"), (1, "#5a6066")])
		+ lin("scale", 0, 0, 1, 1, [(0, "#4e9a3e"), (1, "#24521c")])
		+ lin("chrome", 0, 0, 0, 1, [(0, "#d0d6da"), (0.5, "#6a7278"), (1, "#a8b0b6")]))
	b = []
	# the chef's sleeve and wrist, coming up from the bottom left
	b.append(path("M250 420 L300 300 Q330 250 380 236 L440 262 Q420 330 400 420 Z", "#f2efe8", stroke=INK, sw=6))
	b.append(path("M300 300 Q360 290 430 300", stroke="#c8c4bc", sw=5))
	b.append(path("M330 250 Q350 200 380 190 L430 210 Q440 240 430 262 L380 270 Z", "#a87a4c", stroke=INK, sw=6))
	# the cleaver, its handle in the fist, the blade raised up and to the left
	b.append(group([
		rect(40, 40, 230, 120, "url(#blade)", stroke=INK, sw=6),
		line(46, 154, 264, 154, "#ffffff", 3, 0.7),
		circ(70, 70, 12, "#1a1a1a", stroke=INK, sw=3),
		rect(262, 82, 120, 38, "#5a3a20", rx=8, stroke=INK, sw=5),
		circ(300, 101, 5, "#c8c0a8"), circ(350, 101, 5, "#c8c0a8"),
	], tr="translate(54 76) rotate(24 330 101)"))
	# the fist round the handle
	b.append(path("M350 196 Q360 150 400 148 Q440 150 446 186 Q450 222 420 232 L370 230 Q346 222 350 196 Z", "#b0825a", stroke=INK, sw=6))
	for k in range(3):
		b.append(path("M%d %d Q%d %d %d %d" % (362 + k * 22, 160, 370 + k * 22, 190, 362 + k * 22, 224), stroke=INK, sw=3, op=0.8))
	# the claw from the right: black suit cuff, gold cufflink, green scaled fingers clamped round the wrist, ivory claws
	b.append(path("M680 190 L580 194 Q546 200 536 236 L536 300 Q576 316 680 322 Z", "#141416", stroke=INK, sw=6))
	b.append(path("M578 194 L582 318", stroke="#f2efe8", sw=10))
	b.append(circ(616, 258, 9, "#d8b040", stroke=INK, sw=3))
	b.append(path("M546 206 Q500 200 456 214 Q420 226 404 250 Q394 274 420 290 L470 292 Q450 318 470 336 Q500 348 540 312 L548 290 Z",
		"url(#scale)", stroke=INK, sw=6))
	for (x, y) in ((440, 236), (468, 226), (496, 222), (520, 230), (452, 268), (482, 258), (510, 262), (492, 312), (512, 296)):
		b.append(path("M%d %d q8 -8 16 0" % (x, y), stroke="#1c3c14", sw=3, op=0.7))
	b.append(path("M456 214 Q490 204 524 216 L522 240 Q490 230 458 238 Z", "url(#chrome)", stroke=INK, sw=4, op=0.9))
	for (x0, y0, x1, y1) in ((408, 246, 376, 236), (404, 276, 370, 280), (470, 334, 452, 364), (430, 290, 404, 312)):
		b.append(path("M%d %d L%d %d L%d %d Z" % (x0, y0 - 8, x1, y1, x0, y0 + 8), "#efe6cc", stroke=INK, sw=3))
	prop("ck_catch", W, H, b, defs)


def _teeth(b, x0, x1, y, down, rng, big=1.0):
	x = x0
	while x < x1:
		w = rng.uniform(46, 78) * big
		h = rng.uniform(70, 130) * big * (1 if down else -1)
		tip = x + w * rng.uniform(0.4, 0.6)
		b.append(path("M%s %s Q%s %s %s %s Q%s %s %s %s Z" % (f(x), f(y), f(x + w * 0.1), f(y + h * 0.7), f(tip), f(y + h),
			f(x + w * 0.9), f(y + h * 0.7), f(x + w), f(y)), "#ece2c6", stroke=INK, sw=5))
		b.append(path("M%s %s Q%s %s %s %s" % (f(x + w * 0.25), f(y + h * 0.1), f(x + w * 0.3), f(y + h * 0.6), f(tip - 2), f(y + h * 0.9)),
			stroke="#ffffff", sw=3, op=0.6))
		x += w + rng.uniform(-6, 10)


def ck_jaw_top():
	W, H = 1500, 560
	rng = random.Random(3301)
	defs = (lin("palate", 0, 0, 0, 1, [(0, "#0c0204"), (0.7, "#3a0810"), (1, "#5a0e18")])
		+ lin("snout", 0, 0, 0, 1, [(0, "#1c3a14"), (1, "#2e5a22")]))
	b = []
	b.append(path("M0 0 L1500 0 L1500 400 Q1300 430 750 440 Q200 430 0 400 Z", "url(#palate)"))
	for i in range(7):
		y = 80 + i * 46
		b.append(path("M120 %d Q750 %d 1380 %d" % (y, y + 40, y), stroke="#5a0e18", sw=10, op=0.55))
	b.append(path("M0 380 Q200 420 750 430 Q1300 420 1500 380 L1500 420 Q1300 460 750 470 Q200 460 0 420 Z", "url(#snout)", stroke=INK, sw=6))
	_teeth(b, 20, 1480, 440, True, rng)
	prop("ck_jaw_top", W, H, b, defs)


def ck_jaw_bot():
	W, H = 1500, 460
	rng = random.Random(3302)
	defs = lin("tongue", 0, 0, 0, 1, [(0, "#5a0e18"), (0.4, "#2e060c"), (1, "#0a0204")])
	b = []
	b.append(path("M0 140 Q200 100 750 92 Q1300 100 1500 140 L1500 460 L0 460 Z", "url(#tongue)"))
	b.append(path("M300 220 Q750 150 1200 220 Q750 300 300 220 Z", "#6a1420", op=0.6))
	b.append(path("M0 110 Q200 70 750 62 Q1300 70 1500 110 L1500 150 Q1300 110 750 102 Q200 110 0 150 Z", "#2e5a22", stroke=INK, sw=6))
	_teeth(b, 40, 1460, 104, False, rng, 0.85)
	prop("ck_jaw_bot", W, H, b, defs)


def ck_cleaver():
	W, H = 320, 150
	defs = lin("blade2", 0, 0, 0, 1, [(0, "#e0e6ea"), (0.5, "#9aa2a8"), (1, "#5a6066")])
	b = [rect(10, 14, 196, 112, "url(#blade2)", rx=4, stroke=INK, sw=5)]
	b.append(line(14, 120, 202, 120, "#ffffff", 3, 0.7))
	b.append(circ(36, 40, 10, "#1a1a1a", stroke=INK, sw=3))
	b.append(rect(200, 50, 112, 34, "#5a3a20", rx=8, stroke=INK, sw=5))
	b.append(circ(234, 67, 5, "#c8c0a8"))
	b.append(circ(274, 67, 5, "#c8c0a8"))
	prop("ck_cleaver", W, H, b, defs)


def ck_toque():
	W, H = 240, 200
	b = [ell(120, 176, 104, 16, "#000000", op=0.35)]
	# lying on its side, the puffy top to the right, the band to the left
	b.append(path("M40 70 L96 60 L104 170 L46 168 Z", "#e8e4dc", stroke="#2a1a10", sw=5))
	b.append(path("M96 60 Q120 20 170 34 Q220 30 226 90 Q236 150 186 168 Q140 186 104 170 Z", "#f4f1ea", stroke="#2a1a10", sw=5))
	b.append(path("M130 50 Q150 100 140 160", stroke="#cfcac0", sw=4))
	b.append(path("M170 40 Q190 100 176 160", stroke="#cfcac0", sw=4))
	b.append(path("M40 70 L96 60 L98 92 L42 100 Z", "#dcd8ce", stroke="#2a1a10", sw=3))
	prop("ck_toque", W, H, b)


# ======================================================================== epilogue backgrounds
def _hall(after):
	rng = random.Random(3401)
	W, H = 1280, 720
	HZ = 470
	defs = (lin("hwall", 0, 0, 0, 1, [(0, "#0e1412"), (0.6, "#1a2420"), (1, "#121916")])
		+ lin("moon", 0, 0, 0, 1, [(0, "#9ab8d8"), (1, "#3a5878")])
		+ rad("candle", 0.5, 0.5, 0.5, [(0, "#ffd890", 0.8), (0.4, "#e0a050", 0.25), (1, "#000000", 0)])
		+ rad("beam", 0.5, 0.0, 1.0, [(0, "#9ab8d8", 0.22), (1, "#9ab8d8", 0)])
		+ lin("stairs", 0, 0, 0, 1, [(0, "#1a1410"), (1, "#2c2218")]))
	b = [rect(0, 0, W, H, "url(#hwall)")]
	# panelling
	for x in range(0, W, 160):
		b.append(rect(x + 14, 260, 132, 190, "none", stroke="#26322d", sw=4, op=0.8))
		b.append(rect(x, 0, 10, HZ, "#0b100e", op=0.8))
	b.append(rect(0, 240, W, 12, "#2a3530"))
	# tall arched windows left and right, moonlight
	for x0 in (70, 1080):
		b.append(path("M%d 400 L%d 120 Q%d 40 %d 40 Q%d 40 %d 120 L%d 400 Z" % (x0, x0, x0, x0 + 65, x0 + 130, x0 + 130, x0 + 130), "url(#moon)", stroke="#0a0d0c", sw=10))
		b.append(line(x0 + 65, 44, x0 + 65, 400, "#0a0d0c", 6))
		for y in (130, 210, 290):
			b.append(line(x0, y, x0 + 130, y, "#0a0d0c", 5))
		b.append(poly([(x0, 400), (x0 + 130, 400), (x0 + 260 if x0 < 640 else x0 - 130, 720), (x0 + 60 if x0 < 640 else x0 - 330, 720)], "url(#beam)", 0.6))
	b.append(path(crack_path(150, 120, rng, 6, 18, 1.0), stroke="#cfe0ee", sw=2, op=0.7))
	# the grand staircase, centre back, up to a landing and an arched window
	b.append(path("M560 40 Q560 0 640 0 Q720 0 720 40 L720 230 L560 230 Z", "url(#moon)", stroke="#0a0d0c", sw=10, op=0.8))
	b.append(line(640, 4, 640, 230, "#0a0d0c", 5))
	b.append(rect(440, 230, 400, 26, "#2a2018", stroke="#0a0806", sw=4))
	b.append(poly([(470, 256), (810, 256), (900, HZ), (380, HZ)], "url(#stairs)"))
	for k in range(12):
		u = (k + 1) / 13.0
		y = 256 + (HZ - 256) * u
		xl = 470 - 90 * u
		xr = 810 + 90 * u
		b.append(line(xl, y, xr, y, "#0e0a07", 4, 0.8))
		b.append(line(xl, y + 3, xr, y + 3, "#4a3a28", 2, 0.35))
	# a dark runner up the middle of the stairs
	b.append(poly([(600, 256), (680, 256), (720, HZ), (560, HZ)], "#14303a", 0.85))
	# banisters
	for side in (-1, 1):
		x0, x1 = (470, 380) if side < 0 else (810, 900)
		b.append(line(x0, 216, x1, HZ - 60, "#3a2a1c", 10))
		for k in range(10):
			u = (k + 0.5) / 10.0
			x = x0 + (x1 - x0) * u
			yt = 216 + (HZ - 60 - 216) * u
			yb = 256 + (HZ - 256) * u
			b.append(line(x, yt, x, yb, "#2a1e14", 4))
		b.append(rect(x1 - 12, HZ - 90, 24, 90, "#2a1e14", stroke="#0a0806", sw=3))
		b.append(circ(x1, HZ - 94, 14, "#3a2a1c", stroke="#0a0806", sw=3))
	# portraits on the walls (one hangs crooked)
	for (x, y, w, h, rot) in ((250, 90, 110, 140, 0), (920, 90, 110, 140, 7)):
		tr = "rotate(%d %d %d)" % (rot, x + w // 2, y + h // 2)
		b.append(rect(x, y, w, h, "#1a1612", stroke="#6a5228", sw=8, tr=tr))
		b.append(rect(x + 14, y + 14, w - 28, h - 28, "#262018", tr=tr))
	b.append(path(crack_path(980, 250, rng, 7, 22, 1.4), stroke="#060807", sw=4, op=0.9))
	b.append(path(crack_path(330, 40, rng, 8, 20, 1.6), stroke="#060807", sw=3, op=0.9))
	# the chandelier
	b.append(line(640, 0, 640, 70, "#0a0a0a", 4))
	b.append(ell(640, 96, 120, 26, "none", stroke="#2a2418", sw=8))
	for k in range(9):
		a = TAU * k / 9.0
		x, y = 640 + math.cos(a) * 118, 96 + math.sin(a) * 24
		b.append(rect(x - 4, y - 18, 8, 18, "#d8d0bc", op=0.8))
		if k % 3 != 1:
			b.append(circ(x, y - 24, 22, "url(#candle)"))
			b.append(ell(x, y - 22, 3, 5, "#ffe0a0"))
	# the marble floor in perspective
	VX, VY = 640, 300
	b.append(rect(0, HZ, W, H - HZ, "#1a1a1c"))
	rows = 9
	for r in range(rows):
		v0 = (r / float(rows)) ** 1.5
		v1 = ((r + 1) / float(rows)) ** 1.5
		y0, y1 = HZ + (H - HZ) * v0, HZ + (H - HZ) * v1
		for c in range(-12, 13):
			def X(cc, yy):
				return VX + (cc * 120) * (yy - VY) / (H - VY)
			p = [(X(c, y0), y0), (X(c + 1, y0), y0), (X(c + 1, y1), y1), (X(c, y1), y1)]
			light = (r + c) % 2 == 0
			b.append(poly(p, "#7a7872" if light else "#141416"))
			if light and rng.random() < 0.4:
				x0 = X(c + rng.random(), y0)
				b.append(line(x0, y0, x0 + rng.uniform(-30, 30), y1, "#9a9890", 1.5, 0.5))
	b.append(rect(0, HZ, W, H - HZ, "#0a1018", op=0.35))
	b.append(rect(0, HZ, W, 10, "#0a0c0b"))
	b.append(poly([(80, 720), (330, 470), (500, 470), (560, 720)], "#9ab8d8", 0.06))
	b.append(poly([(1200, 720), (950, 470), (780, 470), (720, 720)], "#9ab8d8", 0.06))
	if after:
		b.append(rect(0, 0, W, H, "#000000", op=0.3))
		# the pool on the marble at the foot of the stairs, where it happened (kept above the textbox), thrown blood up the
		# bottom steps and the banister post, the cleaver where it spun to a stop, the chef's hat
		splat(b, 600, 500, 150, rng, 1.0, 18, 0.14)
		splat(b, 470, 506, 60, rng, 0.95, 8, 0.2)
		b.append(path("M700 492 Q780 486 860 496 Q790 502 702 500 Z", BLOOD, op=0.9))
		for _ in range(46):
			a = rng.uniform(-math.pi, 0.0)
			d = rng.uniform(120, 340)
			b.append(circ(600 + math.cos(a) * d * 1.2, 498 + math.sin(a) * d * 0.5, rng.uniform(2, 6), BLOOD, op=0.9))
		for k in range(7):
			x = rng.uniform(420, 820)
			y = rng.uniform(380, 460)
			b.append(line(x, y, x + rng.uniform(-3, 3), y + rng.uniform(10, 30), BLOOD, rng.uniform(3, 6), 0.9))
		b.append(group([rect(0, 0, 150, 84, "#7a8288", stroke=INK, sw=4), rect(148, 28, 84, 26, "#4a3018", rx=6, stroke=INK, sw=4),
			line(4, 80, 146, 80, "#c8d0d4", 2), circ(18, 18, 7, "#141414")], tr="translate(760 482) rotate(-8) scale(0.45 0.3)"))
		b.append(group([path("M40 70 L96 60 L104 170 L46 168 Z", "#bcb8b0", stroke="#2a1a10", sw=5),
			path("M96 60 Q120 20 170 34 Q220 30 226 90 Q236 150 186 168 Q140 186 104 170 Z", "#c8c4bc", stroke="#2a1a10", sw=5)],
			tr="translate(380 462) scale(0.3) rotate(18 120 100)"))
	bg("end3_hall_after" if after else "end3_hall", b, defs)


OUT_CELL = (4, 9)    # the cell whose light goes out in end3_terrace_out


def _terrace(out):
	rng = random.Random(3501)
	W, H = 1280, 720
	SEA = 392
	defs = (lin("nsky", 0, 0, 0, 1, [(0, "#03050c"), (0.7, "#0c1a2a"), (1, "#1a2c3a")])
		+ lin("nsea", 0, 0, 0, 1, [(0, "#0a1622"), (1, "#03070c")])
		+ rad("halo", 0.5, 0.5, 0.5, [(0, "#d8e4f0", 0.5), (1, "#d8e4f0", 0)])
		+ rad("win", 0.5, 0.5, 0.5, [(0, "#ffd890", 0.75), (1, "#ffd890", 0)])
		+ lin("stone", 0, 0, 0, 1, [(0, "#4a4844"), (1, "#24221f")])
		+ lin("sbeam", 0, 0, 1, 0, [(0, "#e8f0f8", 0.0), (0.5, "#e8f0f8", 0.16), (1, "#e8f0f8", 0.0)]))
	b = [rect(0, 0, W, H, "url(#nsky)")]
	for _ in range(160):
		b.append(circ(rng.uniform(0, W), rng.uniform(0, SEA - 40), rng.uniform(0.6, 1.8), "#ffffff", op=rng.uniform(0.25, 0.85)))
	b.append(circ(1040, 110, 120, "url(#halo)"))
	b.append(circ(1040, 110, 40, "#e8ecef"))
	b.append(circ(1028, 100, 9, "#c8d0d8", op=0.6))
	b.append(rect(0, SEA, W, H - SEA, "url(#nsea)"))
	for k in range(40):
		y = SEA + 6 + (k / 40.0) ** 1.4 * 180
		x = 1040 + rng.uniform(-60, 60) * (1 + (y - SEA) / 80.0)
		b.append(line(x - 30, y, x + 30, y, "#c8d8e8", 2, 0.5 * (1 - k / 40.0)))
	# the island and the Gaol across the water
	isl = [(220, SEA + 2), (300, SEA - 30), (420, SEA - 46), (560, SEA - 60), (760, SEA - 58), (900, SEA - 40), (1010, SEA - 20), (1080, SEA + 2)]
	b.append(poly(isl, "#05080c"))
	b.append(rect(380, SEA - 170, 470, 130, "#070a0f"))
	b.append(rect(330, SEA - 120, 80, 90, "#070a0f"))
	b.append(rect(820, SEA - 140, 90, 110, "#070a0f"))
	for tx in (380, 846):
		b.append(rect(tx - 16, SEA - 230, 34, 70, "#070a0f"))
		b.append(poly([(tx - 24, SEA - 230), (tx + 26, SEA - 230), (tx + 1, SEA - 262)], "#070a0f"))
	b.append(poly([(864, SEA - 228), (1280, SEA - 330), (1280, SEA - 250)], "url(#sbeam)"))
	b.append(circ(864, SEA - 228, 6, "#f0f4f8"))
	# the cell windows: every cell has its little light
	idx = 0
	for row in range(6):
		for col in range(20):
			x = 396 + col * 22.5
			y = SEA - 158 + row * 19
			lit = rng.random() < 0.78 or (row, col) == OUT_CELL
			if lit:
				if out is not None and (row, col) == out:
					b.append(rect(x, y, 8, 10, "#0e1218"))
				else:
					b.append(circ(x + 4, y + 5, 9, "url(#win)"))
					b.append(rect(x, y, 8, 10, "#ffd27a"))
				idx += 1
			else:
				b.append(rect(x, y, 8, 10, "#0e1218"))
	# reflections of the windows in the water
	for k in range(14):
		x = rng.uniform(400, 850)
		b.append(line(x, SEA + 8 + k * 3, x + rng.uniform(6, 18), SEA + 8 + k * 3, "#ffd27a", 2, 0.22))
	# the terrace: flagstones, balustrade, a telescope on its tripod
	b.append(rect(0, 610, W, 110, "#1a1916"))
	for x in range(-40, W, 150):
		b.append(line(x, 610, x - 80, 720, "#0c0b0a", 3))
	b.append(rect(0, 530, W, 20, "url(#stone)", stroke="#0c0b0a", sw=3))
	b.append(rect(0, 600, W, 18, "url(#stone)", stroke="#0c0b0a", sw=3))
	for x in range(20, W, 56):
		b.append(path("M%d 550 Q%d 566 %d 575 Q%d 590 %d 600 L%d 600 Q%d 590 %d 575 Q%d 566 %d 550 Z" % (
			x, x - 8, x - 2, x - 10, x - 2, x + 22, x + 30, x + 22, x + 28, x + 20), "url(#stone)", stroke="#0c0b0a", sw=2))
	b.append(group([
		line(0, 0, -60, 170, "#2a2018", 8), line(0, 0, 60, 170, "#2a2018", 8), line(0, 0, 0, 176, "#2a2018", 8),
		rect(-20, -40, 150, 34, "#8a6a30", rx=10, stroke=INK, sw=5, tr="rotate(-14 0 -20)"),
		rect(-60, -44, 50, 26, "#6a4e20", rx=6, stroke=INK, sw=4, tr="rotate(-14 0 -20)"),
		circ(128, -60, 18, "#4a3a18", stroke=INK, sw=4)], tr="translate(1100 470)"))
	b.append(rect(0, 0, W, H, "#000000", op=0.08))
	bg("end3_terrace_out" if out is not None else "end3_terrace", b, defs)


def main():
	os.makedirs(PROPS, exist_ok=True)
	sp_standby()
	_newsroom(False)
	_newsroom(True)
	_dummy(False)
	_dummy(True)
	sp_press()
	sp_press_front()
	sp_plate()
	sp_plate_under()
	sp_straps()
	sp_camera_taped()
	sp_paper()
	sp_booth()
	wv_wall()
	wv_gate()
	wv_placard()
	wv_lamp()
	ck_catch()
	ck_jaw_top()
	ck_jaw_bot()
	ck_cleaver()
	ck_toque()
	_hall(False)
	_hall(True)
	_terrace(None)
	_terrace(OUT_CELL)


if __name__ == "__main__":
	main()
