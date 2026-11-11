#!/usr/bin/env python3
"""SPLASH TRIAL - Case 3 earthquake, flood and tunnel cutscene art (flow step `quake`).

Writes art/props/qk_*.svg for scripts/screens/quake_screen.gd:
  qk_rail        1280x720 foreground: the Mudlark's promenade rail up close, deck planks, a string of lanterns (A)
  qk_cup         150x120  a teacup on its saucer, standing on the rail (A, rattled in code)
  qk_pillars     1280x720 the cave's rock pillars, each strapped with a crested charge (B; lamps blink in code)
  qk_watch       360x400  Snapjaw's gold pocket watch (hands drawn in code)
  qk_detonator   520x360  the detonator box with its wires
  qk_plunger     400x470  the plunger rod and T-handle with Snapjaw's claw pushing down on it
  qk_stalactite  100x300  a broken-off stalactite (C, falls in code)
  qk_boulder     140x120  a rock chunk thrown out of the bursting wall (D)
  qk_stack       128x220  the top of the Mudlark's forward smokestack, cut out of dr_ship (E, sheared off in code)
  qk_bow         1280x720 point of view from the foredeck: the bow rushing down the tunnel (E)
  qk_sky         1280x720 a real sky over the open sea (F, G)
  qk_cliff       1280x720 the sea cliff with the tunnel mouth the ship shoots out of (F)
  qk_island      1500x720 the island: the prison on its spit and the mansion on the cliff above (G)
  qk_shore       1280x720 the shore with the wrecked Mudlark: the cutscene's last frame (H)
  qk_hat         220x150  a wide lilac hat with a feather (reaction cut-in)
  qk_pots        300x170  a chef's pots and pans, clutched (reaction cut-in)

Usage (from the project root):  python3 tools/gen_quake_art.py [names...]
Only SVG 1.1 basics are used (no text / filters / images / CSS) so Godot's ThorVG rasterizes it.
The toolkit comes from tools/gen_bgs.py, and the Mudlark herself from tools/gen_drain_art.py (both imported read-only),
so the ship is the same ship as in the lake drain. Constants marked "shared with quake_screen.gd" must stay in sync.
"""
import math
import os
import random
import sys

sys.dont_write_bytecode = True
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gen_bgs as GB  # noqa: E402  (helpers only - never modified)
import gen_drain_art as GDA  # noqa: E402  (the ship and cave motifs - never modified)
from gen_bgs import Doc, G, T, fm, smooth, glow, mix, dark, light, blob_pts  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "art", "props")
W, H = 1280, 720

INK = "#2a1a10"
AQUA = "#3ee0d0"
AQUA_L = "#a8fff3"
FUNGUS = "#5ff5e0"
LANTERN = "#ffcf7a"
BRASS = "#d9a845"
BRASS_L = "#ffe39a"
BRASS_D = "#8a6420"
TEAL_P = "#3d918c"
TEAL_D = "#22585a"
CREAM = "#efe8d4"
CREAM_S = "#b9b09a"
WOOD = "#6a4428"
WOOD_D = "#3c2414"
RED_W = "#c8372d"
CROC_G = "#4f8f52"
CROC_GD = "#2f5e37"
CHROME = "#c3ccd6"
CHROME_D = "#7d8a99"
GOLD = "#e7b347"
GOLD_D = "#a8741e"
SNAP_GREEN = "#43a047"

# ---------------------------------------------------------------- shared with quake_screen.gd
CUP_AT = (772, 446)          # qk_rail: where the cup's saucer sits on the top rail (screen px)
CUP_BASE = (75, 112)         # qk_cup: bottom centre of the saucer
CHARGES = [(214, 386, 1.0), (606, 352, 0.62), (884, 334, 0.4), (1062, 324, 0.27)]   # qk_pillars: lamp x, y, scale
WATCH_C = (180, 232)         # qk_watch: centre of the dial
WATCH_R = 112                # qk_watch: dial radius
PLUNGER_ROD = (200, 470)     # qk_plunger: bottom of the rod (sits in the detonator's slot)
DETONATOR_SLOT = (260, 96)   # qk_detonator: the slot the rod goes into
STACK_ORIGIN = (412, 30)     # qk_stack: its top-left corner in dr_ship canvas px
STACK_SIZE = (128, 220)
CUT_X0, CUT_X1 = 412.0, 521.5   # dr_ship canvas px: the sheared part of the forward stack...
CUT_Y, CUT_JAG, CUT_PERIOD = 236.0, 6.0, 14.0   # ...is everything above this jagged line
BOW_VP = (640, 300)          # qk_bow: the vanishing point the deck runs to (= the tunnel's)
TUNNEL_MOUTH = (962, 356)    # qk_cliff: centre of the tunnel mouth
TUNNEL_R = 98
HORIZON = 470                # qk_sky: the sea horizon
ISLAND_SIZE = (1500, 720)


def cut_y(x):
	"""The jagged shear line on the forward stack (same formula as CUT_SHADER in quake_screen.gd)."""
	u = x / CUT_PERIOD
	tri = abs((u - math.floor(u)) * 2.0 - 1.0) * 2.0 - 1.0
	return CUT_Y + CUT_JAG * tri


def cut_poly():
	"""The sheared region (dr_ship canvas px): above the jagged line, between CUT_X0 and CUT_X1."""
	pts_ = [(CUT_X0, -10.0)]
	x = CUT_X0
	while x < CUT_X1:
		pts_.append((x, cut_y(x)))
		x += CUT_PERIOD / 2.0
	pts_.append((CUT_X1, cut_y(CUT_X1)))
	pts_.append((CUT_X1, -10.0))
	return pts_


def poly_d(p):
	return "M" + " L".join("%s %s" % (fm(float(x)), fm(float(y))) for x, y in p) + " Z"


def mudlark(d, cut=False, wheel=True):
	"""The Mudlark from gen_drain_art (canvas 1200x770, bow left). cut=True leaves out the sheared stack top."""
	if cut:
		# everything except the notch above the shear line
		reg = cut_poly()
		outline = [(-50.0, -50.0), (reg[0][0], -50.0)] + reg[1:-1] + [(reg[-1][0], -50.0), (1300.0, -50.0), (1300.0, 900.0), (-50.0, 900.0)]
		cp = d.clip('<path d="%s"/>' % poly_d(outline))
		d.open(clip_path=cp)
	GDA.ship(d)
	if wheel:
		wx, wy = GDA.WHEEL_C
		with G(d, transform=T(wx - 130, wy + GDA.SHIP_DY - 130)):
			GDA.wheel(d)
		GDA.ship_over(d)
	if cut:
		d.close()
		# the jagged stump top
		reg = cut_poly()
		sx, hw = GDA.STACK_X[0], GDA.STACK_HW
		top = [(x, y) for x, y in reg[1:-1] if sx - hw - 1 <= x <= sx + hw + 1]
		if top:
			d.pline(top, "#050407", 4)
			d.pline([(x, y + 3) for x, y in top], BRASS_D, 1.5, opacity=0.7)


# ================================================================== A: the rail
def rail(d):
	rng = random.Random(311)
	# deck planks along the bottom, receding to the right
	deck = [(-20, 640), (1300, 600), (1300, 740), (-20, 740)]
	d.poly(deck, d.vlin(600, 720, [(0, "#7a5232"), (1, "#3e2616")]))
	dd = ""
	for k in range(1, 7):
		f = k / 7.0
		y0 = 640 + 100 * f * f
		y1 = 600 + 140 * f * f
		dd += "M-20 %s L1300 %s " % (fm(y0), fm(y1))
	d.spath(dd, "#2a180c", 2, opacity=0.6)
	for k in range(22):
		x = -20 + k * 64
		d.line(x, 640 - 40 * (x + 20) / 1320 + 4, x - 30, 740, "#2a180c", 1.4, opacity=0.35)
	d.poly([(-20, 632), (1300, 592), (1300, 604), (-20, 646)], TEAL_D)
	# the rail: posts, balusters, top rail (perspective: lower on the left, rising to the right)
	top_l, top_r = 470.0, 432.0
	foot_l, foot_r = 636.0, 596.0
	dd = ""
	for k in range(-1, 46):
		x = -12 + k * 29.5 + (k * k) * 0.06
		if x > 1300:
			break
		yt = top_l + (top_r - top_l) * (x + 20) / 1320.0
		yb = foot_l + (foot_r - foot_l) * (x + 20) / 1320.0
		dd += "M%s %s L%s %s " % (fm(x), fm(yt + 14), fm(x), fm(yb))
	d.spath(dd, INK, 9)
	d.spath(dd, CREAM, 5.5)
	d.spath(dd, "#ffffff", 1.2, opacity=0.5)
	# mid rail
	ym_l, ym_r = 548.0, 512.0
	d.line(-20, ym_l, 1300, ym_r, INK, 12)
	d.line(-20, ym_l, 1300, ym_r, CREAM, 7)
	# posts with brass caps
	for x in (90, 410, 730, 1050):
		yt = top_l + (top_r - top_l) * (x + 20) / 1320.0
		yb = foot_l + (foot_r - foot_l) * (x + 20) / 1320.0
		d.rect(x - 14, yt - 6, 28, yb - yt + 6, d.lin(x - 14, 0, x + 14, 0, [(0, "#d8d0bc"), (0.35, "#ffffff"), (1, "#a59c86")]),
			stroke=INK, stroke_width=3)
		d.rect(x - 14, yb - 30, 28, 30, TEAL_P, stroke=INK, stroke_width=2.5)
		d.ellipse(x, yt - 8, 18, 7, d.rad(x - 5, yt - 11, 16, [(0, BRASS_L), (1, BRASS_D)]), stroke=INK, stroke_width=2.5)
	# top rail (a thick polished cap)
	d.poly([(-20, top_l - 10), (1300, top_r - 10), (1300, top_r + 14), (-20, top_l + 16)],
		d.vlin(top_r - 10, top_l + 16, [(0, "#ffffff"), (0.35, CREAM), (1, CREAM_S)]), stroke=INK, stroke_width=3.5)
	d.line(-20, top_l - 5, 1300, top_r - 5, "#ffffff", 2.5, opacity=0.8)
	d.line(-20, top_l + 14, 1300, top_r + 12, "#8a8270", 3, opacity=0.6)
	# a few scuffs, a coil of rope hung on a post, weed still stuck in the balusters
	for _ in range(16):
		x = rng.uniform(0, 1260)
		y = top_l + (top_r - top_l) * (x + 20) / 1320.0
		d.line(x, y + 2, x + rng.uniform(6, 22), y + 2 - rng.uniform(-1, 1), "#8a8270", 1.4, opacity=0.5)
	with G(d, transform=T(410, 560)):
		for k in range(4):
			d.ellipse(0, 10 + k * 3, 30 - k * 2, 40 - k * 3, "none", stroke=INK, stroke_width=8)
			d.ellipse(0, 10 + k * 3, 30 - k * 2, 40 - k * 3, "none", stroke="#c8a66a", stroke_width=5)
		d.ellipse(0, 10, 30, 40, "none", stroke="#e8d09a", stroke_width=1.2, opacity=0.6)
	for x in (240, 980, 1180):
		yb = foot_l + (foot_r - foot_l) * (x + 20) / 1320.0
		ddw = "M%s %s q8 -24 -2 -50 q-6 -12 4 -26" % (fm(x), fm(yb - 4))
		d.spath(ddw, GDA.WEED, 4, opacity=0.9)
		d.spath(ddw, GDA.WEED_L, 1.5, opacity=0.7)
	# a string of paper lanterns across the top-left (lit; the ship's festoons)
	a, b = (-30, 40), (560, 108)
	d.spath(GDA.string_path(a, b, 38), "#1a1010", 3)
	for i, (lx, ly) in enumerate(GDA.catenary(a, b, 38, 5)):
		col = GDA.LANTERN_COLS[i % 3]
		s = 2.4 - i * 0.18
		GDA.lantern_body(d, lx, ly + 16 * s, col, s, lit=True)
	# the dark edge of the awning top-right
	d.poly([(820, -10), (1300, -10), (1300, 70), (1180, 58), (1040, 40), (900, 18)], "#0c0a14")
	dd = ""
	for k in range(9):
		x = 900 + k * 50
		dd += "M%s %s q25 22 50 %s " % (fm(x), fm(18 + k * 5.6), fm(5.6))
	d.spath(dd, "#3d918c", 6)
	d.spath(dd, "#e8e0cc", 2)


def cup(d):
	cx, base = CUP_BASE
	# saucer
	d.ellipse(cx, base - 6, 62, 12, "#000000", opacity=0.25)
	d.ellipse(cx, base - 10, 60, 13, d.vlin(base - 22, base, [(0, "#ffffff"), (1, "#c9c2b0")]), stroke=INK, stroke_width=3)
	d.ellipse(cx, base - 13, 38, 7, "#d8d0bc", stroke="#8a8270", stroke_width=1.2)
	d.path("M%s %s Q%s %s %s %s" % tuple(fm(float(v)) for v in (cx - 56, base - 8, cx, base - 1, cx + 56, base - 8)), "none",
		stroke=GB.YUZU, stroke_width=2.2)
	# cup body
	top = base - 74
	body = "M%s %s L%s %s L%s %s Q%s %s %s %s Q%s %s %s %s Z" % tuple(fm(float(v)) for v in (
		cx - 40, top, cx + 40, top, cx + 40, base - 34, cx + 36, base - 16, cx, base - 16, cx - 36, base - 16, cx - 40, base - 34))
	d.path(body, d.lin(cx - 40, 0, cx + 40, 0, [(0, "#e8e2d2"), (0.35, "#ffffff"), (1, "#bdb6a4")]), stroke=INK, stroke_width=3.5,
		stroke_linejoin="round")
	# handle
	d.path("M%s %s Q%s %s %s %s" % tuple(fm(float(v)) for v in (cx + 39, top + 14, cx + 70, top + 18, cx + 36, base - 34)),
		"none", stroke=INK, stroke_width=11)
	d.path("M%s %s Q%s %s %s %s" % tuple(fm(float(v)) for v in (cx + 39, top + 14, cx + 70, top + 18, cx + 36, base - 34)),
		"none", stroke="#f4f0e6", stroke_width=6)
	# band + a little yuzu
	d.path("M%s %s Q%s %s %s %s L%s %s Q%s %s %s %s Z" % tuple(fm(float(v)) for v in (
		cx - 40, top + 16, cx, top + 22, cx + 40, top + 16, cx + 40, top + 26, cx, top + 32, cx - 40, top + 26)), GB.YUZU, stroke=INK, stroke_width=1.5)
	GB.yuzu(d, cx - 6, top + 46, 9, rot=-10)
	# rim with tea
	d.ellipse(cx, top, 40, 9, "#f4f0e6", stroke=INK, stroke_width=3)
	d.ellipse(cx, top + 1.5, 33, 6, d.vlin(top - 5, top + 7, [(0, "#c47a2a"), (1, "#7a3e12")]))
	d.ellipse(cx - 10, top, 10, 2, "#ffe0a0", opacity=0.6)
	d.line(cx - 30, top + 12, cx - 30, base - 34, "#ffffff", 3, opacity=0.6)


# ================================================================== B: pillars, watch, detonator
def charge(d, x, y, s):
	"""A Snapjaw charge strapped round a pillar: red sticks, a crested box, a lamp at (x, y)."""
	with G(d, transform=T(x, y, s)):
		# straps
		for dy in (-40, 52):
			d.rect(-96, dy - 7, 192, 14, "#2a2a34", stroke=INK, stroke_width=3)
			d.rect(-96, dy - 7, 192, 4, "#5a5a6a")
		# sticks
		for k in range(5):
			sx_ = -78 + k * 30
			d.rect(sx_ - 13, -66, 26, 140, d.lin(sx_ - 13, 0, sx_ + 13, 0, [(0, "#7c1c17"), (0.4, "#e0503f"), (1, "#7c1c17")]),
				stroke=INK, stroke_width=3, rx=6)
			d.ellipse(sx_, -66, 13, 5, "#f0a080", stroke=INK, stroke_width=2)
		# box with the crest
		d.rect(-58, -34, 116, 84, d.vlin(-34, 50, [(0, "#2f4a36"), (1, "#16241a")]), stroke=INK, stroke_width=4, rx=8)
		d.rect(-50, -26, 100, 68, "none", stroke=GOLD, stroke_width=2.5, rx=5)
		GB.snapjaw_crest(d, 0, 10, 0.42)
		# lamp housing (the code lights it)
		d.rect(-12, -58, 24, 22, "#1a1a22", stroke=INK, stroke_width=3)
		d.circle(0, -60, 13, "#3a1010", stroke=INK, stroke_width=3)
		d.circle(-4, -64, 4, "#ff9a9a", opacity=0.5)
		# wire out to the right
		d.spath("M58 30 C110 40 120 120 170 150", "#101014", 6)
		d.spath("M58 36 C104 50 110 128 160 160", "#7c1c17", 4)


def pillars(d):
	rng = random.Random(4121)
	d.rect(0, 0, W, H, d.vlin(0, H, [(0, "#04050c"), (0.45, "#0b1424"), (1, "#0a0b14")]))
	glow(d, 760, 330, 560, "#1b6f7c", 0.22, ry=200)
	# far wall strata + floor
	for k in range(6):
		y = 220 + k * 30 + rng.uniform(-6, 6)
		dd = "M-40 %s " % fm(y) + " ".join("L%s %s" % (fm(float(x)), fm(y + math.sin(x * 0.007 + k) * 9)) for x in range(0, W + 81, 80))
		d.spath(dd, "#1c2c44" if k % 2 else "#0a0e18", rng.uniform(6, 12), opacity=0.5)
	floor_ = [(-20, 430), (300, 418), (700, 404), (1300, 396), (1300, 740), (-20, 740)]
	d.poly(floor_, d.vlin(396, H, [(0, "#1c1a22"), (0.4, "#2a2220"), (1, "#3a2c22")]))
	for k in range(14):
		f = k / 13.0
		y = 420 + 300 * f ** 1.6
		d.line(-20, y, 1300, y - 30 * (1 - f), "#5c4636", 1 + 2 * f, opacity=0.35)
	# puddles catching the fungus light
	for (px, py, rx) in [(420, 470, 70), (820, 440, 50), (1100, 520, 90), (180, 640, 110)]:
		d.ellipse(px, py, rx, rx * 0.16, d.vlin(py - 10, py + 10, [(0, "#2d6f78"), (1, "#0d222a")]))
		d.ellipse(px - rx * 0.2, py - 2, rx * 0.45, 2, AQUA_L, opacity=0.35)
	# ceiling + stalactites
	ceil = [(-20, -10), (W + 20, -10), (W + 20, 60), (1000, 80), (760, 70), (520, 96), (300, 76), (-20, 92)]
	d.blob(ceil, d.vlin(0, 110, [(0, "#020308"), (1, "#0b1220")]), t=0.5)
	for x in sorted(rng.uniform(0, W) for _ in range(30)):
		GDA.stalactite(d, x, 64 + 18 * math.sin(x * 0.012) + rng.uniform(0, 14), rng.uniform(16, 46), rng.uniform(26, 96), rng, col="#0e1624")
	# pillars, far to near (each a thick column of rock from floor to ceiling)
	specs = [(1062, 42, 0.27), (884, 66, 0.4), (606, 104, 0.62), (214, 172, 1.0)]
	for (cx, hw, s) in specs:
		lit = 0.15 + 0.5 * s
		top_w = hw * 1.5
		foot = 396 + 70 * s
		col = mix("#0d1420", "#22324a", lit)
		p = [(cx - top_w, -10), (cx + top_w, -10), (cx + hw * 1.05, 120), (cx + hw * 0.92, 260), (cx + hw * 1.1, foot - 40), (cx + hw * 1.5, foot),
			(cx - hw * 1.5, foot), (cx - hw * 1.1, foot - 40), (cx - hw * 0.94, 250), (cx - hw * 1.08, 110)]
		d.blob(p, d.lin(cx - hw, 0, cx + hw, 0, [(0, dark(col, 0.45)), (0.4, col), (0.75, light(col, 0.08)), (1, dark(col, 0.5))]), t=0.45)
		for k in range(int(6 + 8 * s)):
			yy = rng.uniform(30, foot - 30)
			d.spath("M%s %s q%s %s %s %s" % (fm(cx - hw * 0.8), fm(yy), fm(hw * 0.8), fm(rng.uniform(-8, 8) * s), fm(hw * 1.6), fm(rng.uniform(-4, 4) * s)),
				dark(col, 0.5), 2 + 3 * s, opacity=0.6)
		d.spath(smooth([(cx + hw * 1.05, 120), (cx + hw * 0.92, 260), (cx + hw * 1.1, foot - 40)], False, 0.5), AQUA, 2 + 2 * s, opacity=0.25)
		GDA.fungus(d, cx - hw * 0.7, foot - 18, 0.5 + 0.6 * s, rng, n=4)
	for (x, y, s) in CHARGES:
		charge(d, x, y + 62 * s, s)
	# the firing wire looping from charge to charge along the floor
	wire = [(1110, 440), (1000, 452), (900, 470), (760, 500), (640, 520), (420, 560), (300, 600), (200, 650), (120, 740)]
	d.spath(smooth(wire, False, 0.6), "#101014", 7)
	d.spath(smooth(wire, False, 0.6), "#7c1c17", 3.5)
	GDA.banner(d, 760, 30, 70, 150)
	GB.vignette(d, 0.55, "#03040a", 0.5)


def watch(d):
	cx, cy = WATCH_C
	r = WATCH_R
	# chain + bow
	for k in range(5):
		d.ellipse(cx + 70 + k * 22, 34 - k * 4, 12, 7, "none", stroke=INK, stroke_width=6)
		d.ellipse(cx + 70 + k * 22, 34 - k * 4, 12, 7, "none", stroke=GOLD, stroke_width=3.5)
	d.ellipse(cx, 60, 30, 26, "none", stroke=INK, stroke_width=13)
	d.ellipse(cx, 60, 30, 26, "none", stroke=GOLD, stroke_width=8)
	d.ellipse(cx, 60, 30, 26, "none", stroke="#fff0b0", stroke_width=2, opacity=0.6)
	d.rect(cx - 18, 82, 36, 26, d.lin(cx - 18, 0, cx + 18, 0, [(0, GOLD_D), (0.4, "#ffe9a0"), (1, GOLD_D)]), stroke=INK, stroke_width=3, rx=5)
	for k in range(4):
		d.line(cx - 14, 87 + k * 5.5, cx + 14, 87 + k * 5.5, GOLD_D, 1.4)
	# case
	d.circle(cx + 6, cy + 8, r + 30, "#000000", opacity=0.35)
	d.circle(cx, cy, r + 30, d.rad(cx - 40, cy - 50, r + 60, [(0, "#fff0b0"), (0.45, GOLD), (1, GOLD_D)]), stroke=INK, stroke_width=5)
	d.circle(cx, cy, r + 18, "none", stroke=GOLD_D, stroke_width=3)
	for k in range(36):
		a = k / 36 * math.tau
		d.line(cx + math.cos(a) * (r + 20), cy + math.sin(a) * (r + 20), cx + math.cos(a) * (r + 28), cy + math.sin(a) * (r + 28), GOLD_D, 2)
	# dial
	d.circle(cx, cy, r, d.rad(cx - 30, cy - 40, r * 1.3, [(0, "#fffdf2"), (0.7, "#f1e8cc"), (1, "#d8c99e")]), stroke=INK, stroke_width=4)
	d.circle(cx, cy, r - 14, "none", stroke="#c9b98a", stroke_width=1.5)
	for k in range(60):
		a = k / 60 * math.tau - math.pi / 2
		big = k % 5 == 0
		r0 = r - (24 if big else 12)
		if k % 15 == 0:
			r0 = r - 34
		d.line(cx + math.cos(a) * r0, cy + math.sin(a) * r0, cx + math.cos(a) * (r - 5), cy + math.sin(a) * (r - 5),
			INK, 7 if k % 15 == 0 else (4 if big else 1.5))
	# the twelve o'clock marker is a little crocodile tooth
	d.path("M%s %s L%s %s L%s %s Z" % tuple(fm(float(v)) for v in (cx - 9, cy - r + 6, cx + 9, cy - r + 6, cx, cy - r + 34)), "#fffbe8",
		stroke=INK, stroke_width=2.5)
	GB.snapjaw_crest(d, cx, cy + 50, 0.34)
	# glass glint
	d.path("M%s %s Q%s %s %s %s Q%s %s %s %s Z" % tuple(fm(float(v)) for v in (
		cx - 80, cy - 40, cx - 60, cy - 90, cx - 10, cy - 100, cx - 50, cy - 80, cx - 80, cy - 40)), "#ffffff", opacity=0.45)


def detonator(d):
	sx, sy = DETONATOR_SLOT
	# wires running off to the right
	d.spath("M420 250 C500 240 520 300 560 320", "#101014", 9)
	d.spath("M420 250 C500 240 520 300 560 320", "#7c1c17", 5)
	d.spath("M420 290 C480 300 500 340 560 350", "#101014", 9)
	d.spath("M420 290 C480 300 500 340 560 350", "#2a2a34", 5)
	# box
	d.rect(70, sy + 10, 380, 250, "#000000", opacity=0.35, rx=10)
	d.rect(60, sy, 380, 250, d.vlin(sy, sy + 250, [(0, "#3a5a40"), (0.5, "#25402c"), (1, "#14241a")]), stroke=INK, stroke_width=5, rx=10)
	d.rect(60, sy, 380, 34, d.vlin(sy, sy + 34, [(0, "#5a7a5c"), (1, "#2f4a36")]), stroke=INK, stroke_width=4, rx=8)
	# hazard stripes along the bottom
	clip = d.clip('<rect x="64" y="%s" width="372" height="40"/>' % fm(sy + 206))
	with G(d, clip_path=clip):
		d.rect(64, sy + 206, 372, 40, "#f2c04a")
		dd = ""
		for k in range(-2, 16):
			x = 64 + k * 30
			dd += "M%s %s L%s %s L%s %s L%s %s Z " % (fm(x), fm(sy + 246), fm(x + 15), fm(sy + 246), fm(x + 45), fm(sy + 206), fm(x + 30), fm(sy + 206))
		d.path(dd, "#1a1410")
	d.line(60, sy + 206, 440, sy + 206, INK, 3)
	# brass plate with the crest
	d.rect(170, sy + 60, 180, 130, d.vlin(sy + 60, sy + 190, [(0, "#ffe9a0"), (0.5, GOLD), (1, GOLD_D)]), stroke=INK, stroke_width=4, rx=10)
	d.rect(180, sy + 70, 160, 110, "none", stroke=GOLD_D, stroke_width=2, rx=6)
	GB.snapjaw_crest(d, 260, sy + 125, 0.72)
	for (x, y) in ((182, sy + 72), (338, sy + 72), (182, sy + 178), (338, sy + 178)):
		d.circle(x, y, 5, "#6a4a1a", stroke=INK, stroke_width=1.5)
	# terminals
	for (x, y, c) in ((400, sy + 150, "#c8372d"), (400, sy + 190, "#2a2a34")):
		d.rect(x - 6, y - 14, 30, 28, "#2a2a34", stroke=INK, stroke_width=3, rx=4)
		d.circle(x + 9, y, 9, BRASS, stroke=INK, stroke_width=2.5)
		d.circle(x + 7, y - 2, 3, BRASS_L)
	# the slot on top
	d.rect(sx - 26, sy - 6, 52, 18, "#0a0a0e", stroke=INK, stroke_width=3, rx=4)
	d.ellipse(sx, sy + 3, 20, 5, "#000000")


def plunger(d):
	rx_, ry_ = PLUNGER_ROD
	bar_y0, bar_y1 = 150, 204
	# rod
	d.rect(rx_ - 15, bar_y1 - 4, 30, ry_ - bar_y1 + 4, d.lin(rx_ - 15, 0, rx_ + 15, 0, [(0, BRASS_D), (0.35, BRASS_L), (1, BRASS_D)]),
		stroke=INK, stroke_width=3.5)
	for y in range(bar_y1 + 40, ry_, 60):
		d.line(rx_ - 13, y, rx_ + 13, y, BRASS_D, 2)
	# T-bar
	d.rect(30, bar_y0, 340, bar_y1 - bar_y0, d.vlin(bar_y0, bar_y1, [(0, BRASS_L), (0.35, BRASS), (1, BRASS_D)]), stroke=INK, stroke_width=4, rx=26)
	d.line(52, bar_y0 + 10, 348, bar_y0 + 10, "#fff6d0", 3, opacity=0.7)
	for x in (38, 362):
		d.circle(x, (bar_y0 + bar_y1) / 2, 34, d.rad(x - 10, bar_y0 + 10, 40, [(0, BRASS_L), (0.6, BRASS), (1, BRASS_D)]), stroke=INK, stroke_width=4)
		d.circle(x - 10, bar_y0 + 14, 8, "#ffffff", opacity=0.45)
	# sleeve coming down from the top right (black tux, white cuff, gold cufflink)
	d.path("M300 -10 L380 -10 L360 70 Q330 96 280 92 L240 66 Z", d.lin(240, 0, 380, 90, [(0, "#2a2634"), (1, "#0c0a10")]), stroke=INK, stroke_width=3.5)
	d.path("M236 64 Q290 100 356 72 L346 100 Q296 122 232 92 Z", "#f4f0e6", stroke=INK, stroke_width=3)
	d.circle(300, 98, 7, GB.GOLD, stroke=INK, stroke_width=2)
	# the back of the claw on top of the bar (green scales left, chrome plates right)
	d.path("M130 152 Q120 112 150 98 L262 96 Q292 106 286 150 Z",
		d.lin(130, 0, 290, 0, [(0, "#3f7f45"), (0.55, "#4f8f52"), (0.56, CHROME), (1, CHROME_D)]), stroke=INK, stroke_width=3.5)
	for k in range(5):
		x = 146 + k * 14
		d.path("M%s %s q7 -8 14 0" % (fm(x), fm(128 + (k % 2) * 10)), "none", stroke=CROC_GD, stroke_width=2)
	d.line(218, 100, 218, 150, CHROME_D, 1.6)
	# four fingers wrapping down over the front of the bar, claws hooked underneath
	for k in range(4):
		x = 150 + k * 34
		chrome = k >= 2
		base = CHROME if chrome else CROC_G
		shade = CHROME_D if chrome else CROC_GD
		d.path("M%s 140 Q%s 128 %s 140 L%s 202 Q%s 216 %s 202 Z" % (fm(x - 15), fm(x), fm(x + 15), fm(x + 16), fm(x), fm(x - 16)),
			d.vlin(128, 216, [(0, light(base, 0.25)), (0.6, base), (1, shade)]), stroke=INK, stroke_width=3)
		d.path("M%s 170 Q%s 164 %s 170" % (fm(x - 13), fm(x), fm(x + 13)), "none", stroke=shade, stroke_width=2.2)
		d.path("M%s 204 Q%s 232 %s 240 Q%s 224 %s 204 Z" % (fm(x - 9), fm(x - 4), fm(x + 2), fm(x + 6), fm(x + 9)), "#fffbe8", stroke=INK, stroke_width=2)
		d.ellipse(x - 5, 146, 5, 3, "#ffffff", opacity=0.4)
	# thumb on the left side
	d.path("M134 150 Q104 154 98 182 Q100 204 124 204 Q138 196 140 178 Z", CROC_G, stroke=INK, stroke_width=3)
	d.path("M102 186 Q98 204 112 208 L108 194 Z", "#fffbe8", stroke=INK, stroke_width=1.5)
	# push lines
	d.spath("M110 70 l-18 -26 M150 60 l-6 -30 M330 130 l26 -18", "#ffffff", 4, opacity=0.8)


# ================================================================== C/D: falling rock
def stalactite_sprite(d):
	rng = random.Random(77)
	x, w, h = 50, 70, 270
	col = "#18233a"
	p = [(x - w / 2, 18), (x - w / 3, 6), (x - 6, 16), (x + 8, 4), (x + w / 3, 14), (x + w / 2, 20)]
	tip = (x + 4, 18 + h)
	path = "M%s %s " % (fm(p[0][0]), fm(p[0][1])) + " ".join("L%s %s" % (fm(float(a)), fm(float(b))) for a, b in p[1:]) + \
		" Q%s %s %s %s Q%s %s %s %s Z" % tuple(fm(float(v)) for v in (x + w * 0.34, 18 + h * 0.5, tip[0], tip[1], x - w * 0.38, 18 + h * 0.45, p[0][0], p[0][1]))
	d.path(path, d.lin(x - w / 2, 0, x + w / 2, 0, [(0, light(col, 0.18)), (0.45, col), (1, dark(col, 0.45))]), stroke="#06070d", stroke_width=3)
	d.spath("M%s 26 Q%s %s %s %s" % (fm(x - w / 2 + 6), fm(x - w * 0.3), fm(18 + h * 0.4), fm(x - w * 0.1), fm(18 + h * 0.72)), AQUA, 4, opacity=0.45)
	for _ in range(6):
		yy = rng.uniform(40, h * 0.7)
		ww = w * (1 - yy / (h + 30)) * 0.8
		d.line(x - ww / 2, yy, x + ww / 2, yy + rng.uniform(-6, 6), dark(col, 0.5), 2.5, opacity=0.7)
	d.path("M%s %s L%s %s L%s %s L%s %s Z" % tuple(fm(float(v)) for v in (x - w / 2, 18, x - w / 3, 6, x + 8, 4, x + w / 2, 20)), "#2c3a52")
	GDA.fungus(d, x - 14, 52, 0.45, rng, n=3, up=False)


def boulder(d):
	rng = random.Random(9)
	p = blob_pts(70, 62, 60, 48, rng, 9, 0.22)
	d.blob(p, d.lin(20, 20, 120, 110, [(0, "#3a4a66"), (0.5, "#1c2638"), (1, "#0a0e18")]), t=0.4, stroke="#06070d", stroke_width=3)
	d.spath("M30 50 Q60 22 100 36", AQUA, 3, opacity=0.35)
	d.spath("M50 70 L70 60 L84 80 M64 92 L80 84", "#06070d", 2.5, opacity=0.8)


# ================================================================== E: the stack top, the bow
def stack(d):
	ox, oy = STACK_ORIGIN
	with G(d, transform=T(-ox, -oy)):
		cp = d.clip('<path d="%s"/>' % poly_d(cut_poly()))
		with G(d, clip_path=cp):
			GDA.ship(d)
		reg = cut_poly()
		sx, hw = GDA.STACK_X[0], GDA.STACK_HW
		bot = [(x, y) for x, y in reg[1:-1] if sx - hw - 1 <= x <= sx + hw + 1]
		if bot:
			d.pline(bot, "#050407", 4)
			d.pline([(x, y - 3) for x, y in bot], BRASS_L, 1.5, opacity=0.6)


def bow(d):
	"""Point of view from the foredeck: the bow runs ahead into the tunnel (projected from 3D, metres)."""
	vx, vy, f, eye = BOW_VP[0], BOW_VP[1], 600.0, 2.2

	def P(x, y, z):
		return (vx + x * f / z, vy + (eye - y) * f / z)

	def half(z):
		return 4.0 if z <= 5.0 else 4.0 * math.sqrt(max(0.0, 1.0 - ((z - 5.0) / 5.0) ** 2))

	zs = [1.0 + k * 0.1 for k in range(91)]
	left = [P(-half(z), 0.0, z) for z in zs]
	right = [P(half(z), 0.0, z) for z in zs]
	d.poly(left + right[::-1], d.vlin(vy + 100, H, [(0, "#3e2616"), (0.5, "#6a4428"), (1, "#8a5a34")]))
	# planks running fore and aft
	dd = ""
	for k in range(-7, 8):
		x = k * 0.5
		zend = 10.0 if k == 0 else max(z for z in zs if half(z) >= abs(x))
		a_, b_ = P(x, 0.0, 1.0), P(x, 0.0, zend)
		dd += "M%s %s L%s %s " % (fm(a_[0]), fm(a_[1]), fm(b_[0]), fm(b_[1]))
	d.spath(dd, "#2a180c", 2, opacity=0.55)
	for z in (1.6, 2.4, 3.4, 4.8, 6.6):
		a_, b_ = P(-half(z), 0.0, z), P(half(z), 0.0, z)
		d.line(a_[0], a_[1], b_[0], b_[1], "#2a180c", 1.2, opacity=0.3)
	# anchor chain from the capstan to the hawse pipe at the tip
	chain = [P(0.0, 0.05, 6.5 + k * 0.25) for k in range(13)]
	d.pline(chain, "#1a1814", 7)
	d.pline(chain, "#8a8478", 3.5)
	# capstan
	cx, cy = P(0.0, 0.0, 6.0)
	s = f / 6.0 / 100.0
	d.ellipse(cx, cy + 4 * s, 60 * s, 16 * s, "#000000", opacity=0.35)
	d.rect(cx - 45 * s, cy - 60 * s, 90 * s, 60 * s, d.lin(cx - 45 * s, 0, cx + 45 * s, 0, [(0, BRASS_D), (0.4, BRASS_L), (1, BRASS_D)]),
		stroke=INK, stroke_width=3.5)
	d.ellipse(cx, cy - 60 * s, 45 * s, 12 * s, BRASS, stroke=INK, stroke_width=3.5)
	d.ellipse(cx, cy - 60 * s, 15 * s, 4 * s, BRASS_D, stroke=INK, stroke_width=2)
	for k in range(5):
		d.line(cx - 36 * s + k * 18 * s, cy - 50 * s, cx - 36 * s + k * 18 * s, cy - 6 * s, BRASS_D, 2)
	# bulwarks and rails along both edges, near to far
	for side in (-1, 1):
		zz = [z for z in zs if z <= 9.95]
		low = [P(side * half(z), 0.0, z) for z in zz]
		hi = [P(side * half(z), 0.32, z) for z in zz]
		d.poly(low + hi[::-1], d.lin(vx, 0, vx + side * 700, 0, [(0, TEAL_D), (1, TEAL_P)]), stroke=INK, stroke_width=3)
		dd = ""
		z = 1.3
		while z < 9.9:
			a_, b_ = P(side * half(z), 0.32, z), P(side * half(z), 1.05, z)
			dd += "M%s %s L%s %s " % (fm(a_[0]), fm(a_[1]), fm(b_[0]), fm(b_[1]))
			z += 0.18 * z
		d.spath(dd, INK, 6)
		d.spath(dd, CREAM, 3)
		for k in range(len(zz) - 1):
			if k % 3:
				continue
			z0, z1 = zz[k], zz[min(k + 3, len(zz) - 1)]
			a_, b_ = P(side * half(z0), 1.05, z0), P(side * half(z1), 1.05, z1)
			wdt = max(3.0, 0.11 * f / z0)
			d.line(a_[0], a_[1], b_[0], b_[1], INK, wdt + 5)
			d.line(a_[0], a_[1], b_[0], b_[1], CREAM, wdt)
	# the flagstaff at the tip with the ship's pennant streaming back
	b0, t0 = P(0.0, 0.3, 9.7), P(0.0, 4.4, 9.7)
	d.line(b0[0], b0[1], t0[0], t0[1], INK, 9)
	d.line(b0[0], b0[1], t0[0], t0[1], WOOD, 5)
	d.circle(t0[0], t0[1], 7, BRASS, stroke=INK, stroke_width=2.5)
	px, py = t0[0], t0[1] + 10
	d.path("M%s %s Q%s %s %s %s Q%s %s %s %s Q%s %s %s %s Z" % tuple(fm(float(v)) for v in (
		px + 2, py, px + 70, py - 14, px + 150, py + 6, px + 120, py + 24, px + 180, py + 40, px + 80, py + 36, px + 2, py + 34)),
		"#5a1f6e", stroke=GB.GOLD, stroke_width=3)
	d.circle(px + 40, py + 18, 7, GB.GOLD)
	# lantern string from above the camera to the staff
	a, b = (-60, 70), (t0[0] - 4, t0[1] + 6)
	d.spath(GDA.string_path(a, b, 90), "#1a1010", 3)
	for i, (lx, ly) in enumerate(GDA.catenary(a, b, 90, 5)):
		sc = 2.3 - i * 0.36
		GDA.lantern_body(d, lx, ly + 14 * sc, GDA.LANTERN_COLS[i % 3], sc, lit=True)


# ================================================================== F/G: sky, cliff, island
def cloud(d, x, y, s, rng, a=1.0):
	p = []
	n = 7
	for i in range(n):
		f = i / (n - 1)
		p.append((x - 120 * s + 240 * s * f, y - (30 + 50 * math.sin(math.pi * f) + rng.uniform(-10, 10)) * s))
	p += [(x + 140 * s, y), (x - 140 * s, y)]
	with G(d, opacity=a if a < 1 else None):
		d.blob(p, d.vlin(y - 90 * s, y, [(0, "#ffffff"), (0.65, "#f2f4ff"), (1, "#b9c4e8")]), t=0.8)
		d.path("M%s %s Q%s %s %s %s" % tuple(fm(float(v)) for v in (x - 120 * s, y - 6 * s, x, y + 6 * s, x + 130 * s, y - 6 * s)), "none",
			stroke="#9aa8d6", stroke_width=3 * s, opacity=0.6)


def sky(d):
	rng = random.Random(5150)
	hz = HORIZON
	d.rect(0, 0, W, hz + 2, d.vlin(0, hz, [(0, "#2f6fd0"), (0.45, "#5e9be6"), (0.85, "#a9d4f2"), (1, "#d8f0f4")]))
	glow(d, 1060, 110, 420, "#fff6d8", 0.5)
	glow(d, 1060, 110, 120, "#ffffff", 0.8)
	d.circle(1060, 110, 46, "#fffbe8", opacity=0.95)
	for (x, y, s, a) in [(180, 150, 1.3, 1.0), (520, 90, 0.9, 0.95), (820, 210, 1.1, 0.9), (330, 330, 0.8, 0.8), (1150, 300, 1.0, 0.85),
			(650, 380, 0.6, 0.7), (960, 410, 0.5, 0.6), (80, 420, 0.55, 0.7)]:
		cloud(d, x, y, s, rng, a)
	# far sea
	d.rect(0, hz, W, H - hz, d.vlin(hz, H, [(0, "#2a8fb0"), (0.3, "#1c6f90"), (1, "#0d3f5c")]))
	d.line(0, hz, W, hz, "#e8fbff", 2, opacity=0.7)
	for k in range(30):
		f = k / 29.0
		y = hz + 6 + (H - hz) * f ** 1.6
		x0 = rng.uniform(-80, W)
		while x0 < W + 40:
			ln = rng.uniform(20, 90) * (0.4 + f * 1.4)
			d.line(x0, y, x0 + ln, y, "#bff4ff", 1 + 2 * f, opacity=0.25 + 0.2 * (1 - f))
			x0 += ln + rng.uniform(40, 160)
	# sun glitter path
	for k in range(26):
		y = hz + 4 + k * 9
		w = 30 + k * 6
		d.line(1060 - w / 2 + rng.uniform(-20, 20), y, 1060 + w / 2 + rng.uniform(-20, 20), y, "#fffbe0", 2 + k * 0.15, opacity=0.5 - k * 0.015)


def cliff(d):
	rng = random.Random(2020)
	mx, my = TUNNEL_MOUTH
	rock = "#7a6a5e"
	edge = [(700, 740), (690, 600), (712, 520), (690, 430), (724, 340), (706, 250), (742, 160), (730, 90), (770, 40), (820, 22), (1300, 10), (1300, 740)]
	d.blob(edge, d.lin(700, 0, 1280, 0, [(0, "#9a8a7a"), (0.25, rock), (0.7, "#5a4c44"), (1, "#3a302c")]), t=0.35, stroke="#2a201c", stroke_width=4)
	# strata and cracks
	for k in range(14):
		y = 60 + k * 44 + rng.uniform(-8, 8)
		x0 = 720 + rng.uniform(0, 60)
		pts_ = [(x0, y)]
		x = x0
		while x < 1290:
			x += rng.uniform(40, 90)
			pts_.append((x, y + rng.uniform(-12, 12)))
		d.spath(smooth(pts_, False, 0.5), "#3a302c", rng.uniform(3, 6), opacity=0.55)
		d.spath(smooth([(px, py + 4) for px, py in pts_], False, 0.5), "#b8a894", 1.5, opacity=0.35)
	for _ in range(10):
		x = rng.uniform(760, 1260)
		y = rng.uniform(60, 600)
		d.spath("M%s %s l%s %s l%s %s l%s %s" % (fm(x), fm(y), fm(rng.uniform(-10, 10)), fm(rng.uniform(20, 40)), fm(rng.uniform(-14, 14)),
			fm(rng.uniform(20, 40)), fm(rng.uniform(-10, 10)), fm(rng.uniform(20, 40))), "#2a201c", 3, opacity=0.7)
	# white streaks (gulls live here)
	for _ in range(12):
		x = rng.uniform(780, 1260)
		y = rng.uniform(80, 520)
		d.spath("M%s %s q%s %s %s %s" % (fm(x), fm(y), fm(rng.uniform(-4, 4)), fm(20), fm(rng.uniform(-3, 3)), fm(rng.uniform(30, 70))), "#f4f0e6", rng.uniform(2, 4), opacity=0.6)
	# grass on top
	top = [(760, 46), (820, 20), (900, 14), (1000, 8), (1100, 12), (1200, 6), (1300, 8), (1300, -20), (760, -20)]
	d.blob(top, d.vlin(-20, 50, [(0, "#3f7a3a"), (1, "#5aa04a")]), t=0.4)
	for k in range(40):
		x = 770 + k * 13 + rng.uniform(-4, 4)
		y = 30 - (x - 760) * 0.035 + rng.uniform(-2, 4)
		d.spath("M%s %s l%s %s" % (fm(x), fm(y), fm(rng.uniform(-6, 6)), fm(rng.uniform(10, 22))), "#3f7a3a", 3)
	# the tunnel mouth: a ragged dark hole, wet stain running down from it
	d.path("M%s %s Q%s %s %s %s L%s %s L%s %s Q%s %s %s %s Z" % tuple(fm(float(v)) for v in (
		mx - 70, my + 60, mx - 90, my + 220, mx - 30, my + 380, mx + 50, my + 380, mx + 80, my + 60, mx + 10, my + 120, mx - 70, my + 60)),
		"#2c2a30", opacity=0.55)
	ring = blob_pts(mx, my, TUNNEL_R + 24, TUNNEL_R * 0.92 + 22, rng, 14, 0.12)
	d.blob(ring, "#4a3e38", t=0.6, stroke="#2a201c", stroke_width=4)
	hole = blob_pts(mx, my, TUNNEL_R, TUNNEL_R * 0.92, rng, 13, 0.1)
	d.blob(hole, d.rad(mx, my, TUNNEL_R, [(0, "#000000"), (0.7, "#06080e"), (1, "#141a24")]), t=0.6)
	d.spath(smooth(hole[7:13], False, 0.6), AQUA, 3, opacity=0.4)
	# rocks at the foot of the cliff
	for (x, y, s) in [(720, 640, 1.0), (800, 690, 1.3), (900, 660, 0.9), (1050, 700, 1.4), (1200, 650, 1.1)]:
		GB.rock(d, x, y, 70 * s, 32 * s, rng, color="#5a4c44", top_light=0.25)


def prison(d, x0, base, rng):
	"""The Gaol: a vast grey fortress on a rock spit (x0 = left edge, base = water line)."""
	stone = "#7b8290"
	stone_d = "#4a505e"
	roof = "#3a3550"
	# the rock it stands on
	d.blob([(x0 - 40, base + 20), (x0 + 20, base - 60), (x0 + 200, base - 90), (x0 + 520, base - 84), (x0 + 700, base - 50), (x0 + 760, base + 20)],
		d.vlin(base - 90, base + 20, [(0, "#6a5c52"), (1, "#3a302c")]), t=0.5, stroke="#2a201c", stroke_width=3)
	wb = base - 70
	# blocks of cells behind the wall, rows of tiny barred windows
	for (bx, bw, bh) in [(x0 + 60, 200, 230), (x0 + 470, 200, 220)]:
		d.rect(bx, wb - bh, bw, bh, d.vlin(wb - bh, wb, [(0, light(stone, 0.06)), (1, stone_d)]), stroke=INK, stroke_width=3)
		d.poly([(bx - 10, wb - bh), (bx + bw / 2, wb - bh - 50), (bx + bw + 10, wb - bh)], roof, stroke=INK, stroke_width=3)
		for r in range(7):
			for c in range(9):
				wx = bx + 14 + c * 20
				wy = wb - bh + 20 + r * 24
				if wy > wb - 160:
					continue
				d.rect(wx, wy, 8, 12, "#1a1c26")
				d.line(wx + 4, wy, wx + 4, wy + 12, "#8a90a0", 1)
	# the central round keep with its lamp room
	kx = x0 + 370
	d.rect(kx - 70, wb - 400, 140, 400 - 150, d.lin(kx - 70, 0, kx + 70, 0, [(0, stone_d), (0.35, light(stone, 0.15)), (1, dark(stone, 0.4))]), stroke=INK, stroke_width=3)
	for r in range(10):
		for c in range(4):
			wy = wb - 380 + r * 24
			wx = kx - 44 + c * 26
			d.rect(wx, wy, 8, 13, "#1a1c26")
			d.line(wx + 4, wy, wx + 4, wy + 13, "#8a90a0", 1)
	d.rect(kx - 84, wb - 412, 168, 18, stone, stroke=INK, stroke_width=3)
	d.rect(kx - 44, wb - 470, 88, 58, "#2a2e3a", stroke=INK, stroke_width=3)
	d.rect(kx - 36, wb - 462, 72, 42, "#cfe6ee", opacity=0.6)
	for k in range(3):
		d.line(kx - 36 + k * 24 + 12, wb - 462, kx - 36 + k * 24 + 12, wb - 420, "#2a2e3a", 3)
	d.poly([(kx - 54, wb - 470), (kx, wb - 520), (kx + 54, wb - 470)], roof, stroke=INK, stroke_width=3)
	d.line(kx, wb - 520, kx, wb - 546, INK, 3)
	d.path("M%s %s l26 6 l-26 6 Z" % (fm(kx), fm(wb - 546)), SNAP_GREEN, stroke=INK, stroke_width=1.5)
	# outer wall with crenellations, in front of the blocks
	d.rect(x0 + 30, wb - 150, 660, 150, d.vlin(wb - 150, wb, [(0, light(stone, 0.12)), (1, stone_d)]), stroke=INK, stroke_width=3)
	dd = ""
	for k in range(34):
		x = x0 + 34 + k * 19.5
		dd += "M%s %s h11 v-12 h-11 Z " % (fm(x), fm(wb - 150))
	d.path(dd, stone, stroke=INK, stroke_width=2)
	for k in range(6):
		y = wb - 130 + k * 22
		d.line(x0 + 34, y, x0 + 686, y, stone_d, 1.4, opacity=0.6)
	# the sea gate
	gx = x0 + 300
	d.path("M%s %s L%s %s Q%s %s %s %s L%s %s Z" % tuple(fm(float(v)) for v in (gx, wb, gx, wb - 70, gx + 40, wb - 110, gx + 80, wb - 70, gx + 80, wb)), "#14161e",
		stroke=INK, stroke_width=3)
	for k in range(5):
		d.line(gx + 8 + k * 16, wb - 90 + abs(k - 2) * 8, gx + 8 + k * 16, wb, "#5a6070", 3)
	# square corner towers
	for tx in (x0 + 30, x0 + 650):
		d.rect(tx - 20, wb - 260, 80, 260, d.lin(tx - 20, 0, tx + 60, 0, [(0, stone_d), (0.4, stone), (1, dark(stone, 0.35))]), stroke=INK, stroke_width=3)
		dd = ""
		for k in range(4):
			dd += "M%s %s h12 v-14 h-12 Z " % (fm(tx - 16 + k * 20), fm(wb - 260))
		d.path(dd, stone, stroke=INK, stroke_width=2)
		for r in range(6):
			d.rect(tx + 14, wb - 236 + r * 34, 10, 16, "#1a1c26")
	# grime streaks + spray at the base
	for _ in range(30):
		x = rng.uniform(x0 + 40, x0 + 680)
		d.line(x, wb - rng.uniform(10, 140), x + rng.uniform(-2, 2), wb, "#3a3e4a", rng.uniform(1, 3), opacity=0.35)


def mansion(d, cx, base, rng):
	"""Warden's Rest on the cliff top: a grand gabled house with wings, chimneys and a tower, cracked."""
	wall = "#e8dcc4"
	wall_d = "#b8a88c"
	roof = "#3a3550"
	roof_l = "#56507a"
	trim = "#8a6a4a"

	def block(x, y, w, h, gable=True, rows=2, cols=4):
		d.rect(x, y, w, h, d.vlin(y, y + h, [(0, light(wall, 0.1)), (1, wall_d)]), stroke=INK, stroke_width=3)
		d.line(x, y + 6, x + w, y + 6, trim, 3)
		if gable:
			d.poly([(x - 10, y), (x + w / 2, y - h * 0.55), (x + w + 10, y)], d.vlin(y - h * 0.55, y, [(0, roof_l), (1, roof)]), stroke=INK, stroke_width=3)
			d.circle(x + w / 2, y - h * 0.22, 7, "#1a2030", stroke=trim, stroke_width=2)
		else:
			d.poly([(x - 10, y), (x + 14, y - 36), (x + w - 14, y - 36), (x + w + 10, y)], d.vlin(y - 36, y, [(0, roof_l), (1, roof)]), stroke=INK, stroke_width=3)
		for r in range(rows):
			for c in range(cols):
				wx = x + (c + 0.5) * w / cols - 7
				wy = y + 18 + r * (h - 28) / rows
				d.rect(wx, wy, 14, 22, "#2a3448", stroke=trim, stroke_width=1.8)
				d.line(wx + 7, wy, wx + 7, wy + 22, trim, 1.2)
				d.path("M%s %s l4 0 l-4 10 Z" % (fm(wx + 2), fm(wy + 2)), "#9fd6e0", opacity=0.4)

	# terrace wall along the cliff edge
	d.rect(cx - 280, base - 14, 560, 14, "#cfc2a8", stroke=INK, stroke_width=2.5)
	dd = ""
	for k in range(28):
		dd += "M%s %s v-14 " % (fm(cx - 276 + k * 20), fm(base - 14))
	d.spath(dd, "#cfc2a8", 4)
	d.line(cx - 280, base - 28, cx + 280, base - 28, "#cfc2a8", 4)
	# wings + centre block + tower
	block(cx - 250, base - 96, 150, 82, gable=False, rows=2, cols=4)
	block(cx + 100, base - 96, 150, 82, gable=False, rows=2, cols=4)
	block(cx - 100, base - 140, 200, 126, gable=True, rows=3, cols=5)
	# tower with a clock face (no hands that read as a time)
	tx = cx + 150
	d.rect(tx - 22, base - 200, 44, 104, d.vlin(base - 200, base - 96, [(0, light(wall, 0.1)), (1, wall_d)]), stroke=INK, stroke_width=3)
	d.poly([(tx - 30, base - 200), (tx, base - 250), (tx + 30, base - 200)], roof, stroke=INK, stroke_width=3)
	d.circle(tx, base - 176, 12, "#f4f0e6", stroke=INK, stroke_width=2)
	d.line(tx, base - 250, tx, base - 268, INK, 2)
	# chimneys
	for (x, y) in [(cx - 200, base - 132), (cx - 140, base - 132), (cx + 40, base - 196), (cx + 200, base - 132)]:
		d.rect(x - 8, y - 30, 16, 34, "#9a6a4a", stroke=INK, stroke_width=2)
		d.rect(x - 11, y - 34, 22, 6, "#6a4a32", stroke=INK, stroke_width=1.5)
	# the earthquake crack down the facade
	d.pline([(cx - 20, base - 140), (cx - 8, base - 112), (cx - 26, base - 86), (cx - 10, base - 56), (cx - 22, base - 30)], INK, 3)
	d.pline([(cx + 120, base - 96), (cx + 132, base - 70), (cx + 122, base - 44)], INK, 2.5)
	# grand steps down to the terrace
	for k in range(4):
		d.rect(cx - 34 - k * 6, base - 14 - (4 - k) * 4, 68 + k * 12, 4, "#d8ccb4", stroke=INK, stroke_width=1)


def island(d):
	"""Seen from the sea: the cliff-top house at the back, the prison on its own rock in front, across a channel."""
	rng = random.Random(777)
	IW, IH = ISLAND_SIZE
	sea_y = 660
	# distant hazy hills behind
	d.blob([(260, sea_y), (420, 430), (640, 380), (900, 400), (1180, 360), (1380, 430), (1470, sea_y)], "#9cb8cc", t=0.5, opacity=0.75)
	# the main island: a tall cliff with a plateau on top
	cl = [(360, sea_y + 6), (420, 560), (470, 470), (520, 400), (600, 352), (720, 330), (900, 318), (1140, 322), (1290, 300), (1360, 330),
		(1420, 420), (1470, 540), (1500, sea_y + 6)]
	cp = d.clip('<path d="%s"/>' % smooth(cl, True, 0.35))
	d.blob(cl, d.lin(360, 0, 1500, 0, [(0, "#a8988a"), (0.35, "#8a7a6e"), (0.8, "#6a5c54"), (1, "#4a3e38")]), t=0.35)
	with G(d, clip_path=cp):
		for k in range(12):
			y = 350 + k * 28
			pts_ = [(360, y + rng.uniform(-6, 6))]
			x = 360.0
			while x < 1500:
				x += rng.uniform(50, 110)
				pts_.append((x, y + rng.uniform(-9, 9)))
			d.spath(smooth(pts_, False, 0.5), "#4a3e38", rng.uniform(2, 3.5), opacity=0.45)
			d.spath(smooth([(px, py + 3) for px, py in pts_], False, 0.5), "#c8b8a4", 1.2, opacity=0.3)
		for _ in range(16):
			x = rng.uniform(420, 1460)
			y = rng.uniform(360, 620)
			d.spath("M%s %s l%s %s l%s %s" % (fm(x), fm(y), fm(rng.uniform(-8, 8)), fm(rng.uniform(16, 30)), fm(rng.uniform(-10, 10)), fm(rng.uniform(16, 30))),
				"#3a302c", 2.5, opacity=0.6)
		# the zig-zag cliff path down to a cove on the right
		path = [(1300, 318), (1372, 362), (1326, 400), (1396, 446), (1350, 490), (1420, 548), (1450, 640)]
		d.spath(smooth(path, False, 0.35), "#b8aa94", 2.5, opacity=0.55)
		# grass on the plateau
		d.blob([(560, 366), (600, 350), (720, 328), (900, 316), (1140, 320), (1290, 298), (1360, 330), (1380, 344), (1140, 336), (900, 334), (720, 346)],
			d.vlin(296, 350, [(0, "#6ab35a"), (1, "#3f7a3a")]), t=0.5)
	d.spath(smooth(cl, True, 0.35), "#2a201c", 3)
	# Warden's Rest on the plateau
	with G(d, transform=T(980, 324, 1.1)):
		mansion(d, 0, 0, rng)
	# a haze over everything at the back
	d.blob(cl, "#c8dcec", t=0.35, opacity=0.18)
	# the prison on its own rock, in front
	prison(d, 30, sea_y + 20, rng)
	# surf along the foot of everything
	for (x0, x1, y0) in [(0, 820, sea_y + 16), (720, 1500, sea_y + 2)]:
		x = x0
		while x < x1:
			w = rng.uniform(20, 70)
			d.line(x, y0 + rng.uniform(-4, 4), x + w, y0 + rng.uniform(-4, 4), "#ffffff", rng.uniform(2, 4), opacity=0.75)
			x += w + rng.uniform(10, 50)


def shore(d):
	"""The island's shore the morning after: the wrecked Mudlark on the pebbles, the cliff path up to the house."""
	rng = random.Random(4242)
	hz = 300
	d.rect(0, 0, W, hz, d.vlin(0, hz, [(0, "#4f86d8"), (0.7, "#a9d4f2"), (1, "#d8f0f4")]))
	for (x, y, s, a) in [(200, 120, 1.0, 0.95), (620, 70, 0.7, 0.9), (420, 220, 0.6, 0.7)]:
		cloud(d, x, y, s, rng, a)
	d.rect(0, hz, W, 120, d.vlin(hz, hz + 120, [(0, "#2a8fb0"), (1, "#1c6f90")]))
	d.line(0, hz, W, hz, "#e8fbff", 2, opacity=0.7)
	for k in range(14):
		y = hz + 8 + k * 8
		x0 = rng.uniform(-40, 200)
		while x0 < 900:
			ln = rng.uniform(20, 70)
			d.line(x0, y, x0 + ln, y, "#bff4ff", 1.5, opacity=0.3)
			x0 += ln + rng.uniform(40, 140)
	# the cliff on the right, with the path climbing to the house
	cl = [(820, hz + 150), (850, 290), (890, 210), (950, 150), (1030, 112), (1300, 98), (1300, hz + 170)]
	cp = d.clip('<path d="%s"/>' % smooth(cl, True, 0.4))
	d.blob(cl, d.lin(820, 0, 1280, 0, [(0, "#9a8a7a"), (0.4, "#7a6a5e"), (1, "#4a3e38")]), t=0.4)
	with G(d, clip_path=cp):
		for k in range(9):
			y = 130 + k * 36
			pts_ = [(820, y + rng.uniform(-6, 6))]
			x = 820.0
			while x < 1300:
				x += rng.uniform(50, 100)
				pts_.append((x, y + rng.uniform(-8, 8)))
			d.spath(smooth(pts_, False, 0.5), "#3a302c", 3, opacity=0.5)
			d.spath(smooth([(px, py + 3) for px, py in pts_], False, 0.5), "#c8b8a4", 1.2, opacity=0.3)
		path = [(1250, 112), (1160, 166), (1236, 222), (1132, 284), (1204, 344), (1100, 414), (1130, 470)]
		d.spath(smooth(path, False, 0.35), "#5a4c44", 7, opacity=0.35)
		d.spath(smooth(path, False, 0.35), "#cfc2a8", 3.5, opacity=0.7)
		for (x, y) in path[1:-1]:
			d.line(x, y, x, y - 14, "#5a3a20", 3)
			d.line(x - 8, y - 10, x + 8, y - 10, "#5a3a20", 2)
		d.blob([(950, 152), (1030, 112), (1300, 98), (1300, 120), (1030, 128), (960, 166)], d.vlin(96, 166, [(0, "#6ab35a"), (1, "#3f7a3a")]), t=0.4)
	d.spath(smooth(cl, True, 0.4), "#2a201c", 3)
	with G(d, transform=T(1170, 106, 0.42)):
		mansion(d, 0, 0, rng)
	# beach: wet sand at the water's edge, pebbles toward us
	beach = [(-20, hz + 110), (300, hz + 96), (700, hz + 116), (1000, hz + 150), (1300, hz + 140), (1300, H + 20), (-20, H + 20)]
	d.blob(beach, d.vlin(hz + 96, H, [(0, "#b8a27e"), (0.3, "#cdb78e"), (1, "#a58c66")]), t=0.4)
	d.spath(smooth(beach[:5], False, 0.4), "#ffffff", 4, opacity=0.7)
	d.spath(smooth([(x, y + 10) for x, y in beach[:5]], False, 0.4), "#7a6a4e", 3, opacity=0.4)
	for _ in range(260):
		x = rng.uniform(-10, W + 10)
		y = rng.uniform(hz + 130, H + 10)
		f = (y - hz) / (H - hz)
		r = rng.uniform(2, 6) * (0.4 + f)
		c = rng.choice(["#8a7a6a", "#a8988a", "#6a5c52", "#c8b8a4", "#5a4c44"])
		d.ellipse(x, y, r * 1.4, r, c, opacity=0.9)
	# the wreck: the Mudlark aground, listing, half in the sand, forward stack sheared
	with G(d, transform="translate(360 196) rotate(-7) scale(0.44)"):
		mudlark(d, cut=True, wheel=True)
	# sand drifted up over her keel
	d.blob([(330, 520), (520, 470), (760, 452), (900, 480), (940, 540), (330, 560)], d.vlin(450, 560, [(0, "#d6c29a"), (1, "#bfa77e")]), t=0.5)
	d.spath(smooth([(330, 520), (520, 470), (760, 452), (900, 480)], False, 0.5), "#8a7a5a", 2.5, opacity=0.6)
	# debris strewn along the tide line (kept to the middle, the lower corners stay calm)
	with G(d, transform=T(470, 540, 0.8, rot=-12)):
		d.rect(-40, -30, 80, 60, d.lin(-40, 0, 40, 0, [(0, "#8a5a34"), (1, "#5a3a20")]), stroke=INK, stroke_width=3)
		d.line(-40, 0, 40, 0, "#3c2414", 3)
		GB.snapjaw_crest(d, 0, -2, 0.2)
	with G(d, transform=T(640, 560, 0.7, rot=74)):
		d.rect(-30, -44, 60, 88, d.lin(-30, 0, 30, 0, [(0, "#6a4428"), (0.5, "#9a6a40"), (1, "#5a3a20")]), stroke=INK, stroke_width=3, rx=20)
		d.line(-30, -20, 30, -20, "#2a2a32", 4)
		d.line(-30, 20, 30, 20, "#2a2a32", 4)
	with G(d, transform=T(780, 540, 0.8, rot=8)):
		d.path("M-36 -20 L36 -20 L28 18 L-28 18 Z", d.lin(-36, 0, 36, 0, [(0, "#8a5a34"), (0.5, "#b07a48"), (1, "#6a4426")]), stroke=INK, stroke_width=3)
		d.line(-34, -8, 34, -8, "#c0c4cc", 3)
		d.ellipse(0, -20, 36, 6, "#3a9aa0", stroke=INK, stroke_width=2)
	for (x, y, c) in [(560, 590, "#e8553d"), (860, 580, "#f2c04a"), (700, 610, "#f08a3a")]:
		d.ellipse(x, y, 10, 13, c, stroke=INK, stroke_width=2)
		d.rect(x - 5, y - 15, 10, 4, "#22160f")
	# seaweed and a long wet streak where she slid in
	for _ in range(18):
		x = rng.uniform(340, 960)
		y = rng.uniform(hz + 150, hz + 300)
		dd = "M%s %s q%s %s %s %s" % (fm(x), fm(y), fm(rng.uniform(-10, 10)), fm(rng.uniform(-6, 6)), fm(rng.uniform(20, 50)), fm(rng.uniform(-4, 4)))
		d.spath(dd, GDA.WEED, 4, opacity=0.8)
	GB.vignette(d, 0.25, "#1a2030", 0.6)


# ================================================================== cut-in props
def hat(d):
	cx, cy = 110, 92
	d.ellipse(cx + 4, cy + 10, 104, 22, "#000000", opacity=0.25)
	d.ellipse(cx, cy, 104, 26, d.vlin(cy - 26, cy + 26, [(0, "#e6d4f2"), (1, "#a888c4")]), stroke=INK, stroke_width=4)
	d.path("M%s %s Q%s %s %s %s Q%s %s %s %s Z" % tuple(fm(float(v)) for v in (cx - 52, cy - 4, cx - 50, cy - 64, cx, cy - 66, cx + 50, cy - 64, cx + 52, cy - 4)),
		d.lin(cx - 52, 0, cx + 52, 0, [(0, "#b898d4"), (0.4, "#e2cef0"), (1, "#9a7ab8")]), stroke=INK, stroke_width=4)
	d.path("M%s %s Q%s %s %s %s L%s %s Q%s %s %s %s Z" % tuple(fm(float(v)) for v in (
		cx - 52, cy - 10, cx, cy - 2, cx + 52, cy - 10, cx + 52, cy - 24, cx, cy - 16, cx - 52, cy - 24)), "#6a3a8e", stroke=INK, stroke_width=2.5)
	# bow
	d.path("M%s %s l-24 -14 l2 28 Z M%s %s l24 -14 l-2 28 Z" % (fm(cx + 30), fm(cy - 16), fm(cx + 30), fm(cy - 16)), "#8a4ab0", stroke=INK, stroke_width=2.5)
	d.circle(cx + 30, cy - 16, 6, "#b070d8", stroke=INK, stroke_width=2)
	# feather
	d.path("M%s %s Q%s %s %s %s Q%s %s %s %s Z" % tuple(fm(float(v)) for v in (cx + 36, cy - 30, cx + 100, cy - 120, cx + 110, cy - 128, cx + 70, cy - 60, cx + 36, cy - 30)),
		"#f6f0ff", stroke=INK, stroke_width=2.5)
	d.spath("M%s %s Q%s %s %s %s" % tuple(fm(float(v)) for v in (cx + 38, cy - 32, cx + 80, cy - 80, cx + 108, cy - 126)), "#b898d4", 2)
	d.ellipse(cx - 30, cy - 46, 14, 6, "#ffffff", opacity=0.5)


def pots(d):
	# frying pan behind
	with G(d, transform=T(70, 96, 1.0, rot=-24)):
		d.rect(40, -10, 110, 18, d.lin(0, -10, 0, 8, [(0, "#4a3a2a"), (1, "#22180e")]), stroke=INK, stroke_width=3, rx=8)
		d.ellipse(0, 0, 64, 52, d.rad(-14, -16, 70, [(0, "#5a5a66"), (1, "#22222a")]), stroke=INK, stroke_width=4)
		d.ellipse(0, 0, 50, 40, "#2a2a32", stroke="#6a6a76", stroke_width=2)
	# big copper pot with a lid
	cx, cy = 168, 108
	d.path("M%s %s L%s %s Q%s %s %s %s Q%s %s %s %s Z" % tuple(fm(float(v)) for v in (cx - 72, cy - 40, cx + 72, cy - 40, cx + 70, cy + 50, cx, cy + 56, cx - 70, cy + 50, cx - 72, cy - 40)),
		d.lin(cx - 72, 0, cx + 72, 0, [(0, "#8a4a22"), (0.35, "#f0a060"), (0.6, "#c8703a"), (1, "#6a3418")]), stroke=INK, stroke_width=4)
	for side in (-1, 1):
		d.path("M%s %s q%s -10 %s 8" % (fm(cx + side * 72), fm(cy - 26), fm(side * 22), fm(side * 4)), "none", stroke=INK, stroke_width=9)
		d.path("M%s %s q%s -10 %s 8" % (fm(cx + side * 72), fm(cy - 26), fm(side * 22), fm(side * 4)), "none", stroke="#c8703a", stroke_width=5)
	d.ellipse(cx, cy - 42, 76, 14, d.vlin(cy - 56, cy - 28, [(0, "#d0d4dc"), (1, "#8a90a0")]), stroke=INK, stroke_width=3.5)
	d.ellipse(cx, cy - 56, 14, 8, "#2a2a32", stroke=INK, stroke_width=2.5)
	d.line(cx - 40, cy - 20, cx - 40, cy + 40, "#ffd0a0", 4, opacity=0.6)
	# a ladle sticking up
	d.line(250, 150, 282, 14, INK, 10)
	d.line(250, 150, 282, 14, "#c0c4cc", 5)
	d.ellipse(286, 12, 18, 12, "#c0c4cc", stroke=INK, stroke_width=3)
	# little motion ticks (he is shaking)
	d.spath("M20 40 l-14 -8 M24 60 l-16 2 M290 70 l14 -6 M288 90 l16 2", "#ffffff", 4, opacity=0.8)


ITEMS = {
	"qk_rail": (W, H, rail),
	"qk_cup": (150, 120, cup),
	"qk_pillars": (W, H, pillars),
	"qk_watch": (360, 400, watch),
	"qk_detonator": (520, 360, detonator),
	"qk_plunger": (400, 470, plunger),
	"qk_stalactite": (100, 300, stalactite_sprite),
	"qk_boulder": (140, 120, boulder),
	"qk_stack": (STACK_SIZE[0], STACK_SIZE[1], stack),
	"qk_bow": (W, H, bow),
	"qk_sky": (W, H, sky),
	"qk_cliff": (W, H, cliff),
	"qk_island": (ISLAND_SIZE[0], ISLAND_SIZE[1], island),
	"qk_shore": (W, H, shore),
	"qk_hat": (220, 150, hat),
	"qk_pots": (300, 170, pots),
}


def main():
	only = set(a for a in sys.argv[1:] if not a.startswith("-"))
	os.makedirs(OUT, exist_ok=True)
	for name, (w, h, fn) in ITEMS.items():
		if only and name not in only:
			continue
		d = Doc(w, h)
		fn(d)
		txt = d.svg()
		with open(os.path.join(OUT, name + ".svg"), "w", encoding="utf-8") as f:
			f.write(txt)
		print("%-14s %6.1f KB" % (name, len(txt) / 1024.0))


if __name__ == "__main__":
	main()
