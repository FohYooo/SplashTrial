#!/usr/bin/env python3
"""SPLASH TRIAL - Chapter 3 Truth Drop icon generator.

Writes art/props/clue_<id>.svg (200x200, transparent) for Case 3's Truth Drops (scripts/data/clues.gd ORDER3,
OPTIONAL3, TRIAL3). Same item-card style as the Case 1 and 2 icons: bold #2a1a10 outlines, flat cel shading, a ground
shadow, no text (writing is scribble glyphs; the one letter drawn, a small e, is a path).
SPOILERS: the drawings follow the Truth Drops' descriptions.

Usage (from the project root):
  python3 tools/gen_clue_icons3.py                      # write them all
  python3 tools/gen_clue_icons3.py --only shaft_pen,bait_tin
Only SVG 1.1 basics are used (no text, filters, images, styles) so Godot's ThorVG rasterizes it.
The SVG toolkit comes from tools/gen_bgs.py (imported read-only).
"""
import math
import os
import random
import sys

sys.dont_write_bytecode = True
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gen_bgs as B  # noqa: E402  (stdlib-only sibling module; main() is guarded)

Doc, G, T = B.Doc, B.G, B.T
fm, mix, dark, light, smooth = B.fm, B.mix, B.dark, B.light, B.smooth
glyphs, sparkle, glow, snapjaw_crest, ishadow = B.glyphs, B.sparkle, B.glow, B.snapjaw_crest, B.ishadow
INK, GOLD, GOLD_D, CHROME, CHROME_D, YUZU = B.INK, B.GOLD, B.GOLD_D, B.CHROME, B.CHROME_D, B.YUZU
OL = B.OL

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

PAPER = "#fbf6ea"
SCRIBBLE = "#5a4a3a"
WOOD = "#9a6236"
WOOD_D = "#6a3e1e"
WOOD_L = "#c48a52"
OAK = "#7a4a26"
GREEN = "#2f6b4c"
GREEN_D = "#1e4a34"
LILAC = "#c4a2df"
LILAC_D = "#9474bd"
PINK = "#ff7eb9"
DUST = "#e9e4da"
GREY_DUST = "#9a958c"
BRASS = "#e2a93a"
BRASS_L = "#ffe08a"
BRASS_D = "#9a6418"
PEN = "#1a1a20"
CHEW = "#e6c890"
SILVER = "#c3ccd6"
SILVER_D = "#7d8a99"
STAMP = "#ff8a1e"

IDS = [
	"rules3", "snapjaw_file3", "ledger_read", "bat_bite", "grub_soup",
	"fallen_bookcase", "wall_anchor", "cup_ring", "desk_contents", "nibs_blotter", "arm_no_bruise", "nibs_mouth",
	"door_scratches", "tray_grains", "bell_tape", "pantry_glitter", "old_puddle", "manual_injuries", "manual_illness",
	"powder_record", "lulu_tin", "bait_tin", "generator_log", "fitting_ticket", "passage_door", "passage_tracks",
	"shawl_hem", "hat_feather", "pen_case", "shaft_pen", "gallery_clock", "dinner_sketch", "photo_roll", "gallery_grate",
	"nibs_cup", "nibs_sheet", "scene_photos",
	"packet_log", "conservatory_sketch", "watch_roster", "terrace_mud", "ledger_terrace", "ledger_hall", "ledger_dining",
	"ledger_kitchen", "ledger_music", "ledger_library", "ledger_wing", "burned_glove", "painted_page", "dead_camera",
	"moustache_wax", "music_box",
]


def P(*v):
	return tuple(fm(float(x)) for x in v)


# --------------------------------------------------------------------------------------
# shared bits
# --------------------------------------------------------------------------------------

def sheet(d, x, y, w, h, rot=0.0, rows=5, seed=1, fill=PAPER, sw=3.5, margin=False):
	"""A sheet of paper with scribbled lines, rotated about its centre."""
	rng = random.Random(seed)
	with G(d, transform="rotate(%s %s %s)" % P(rot, x + w / 2, y + h / 2)):
		d.rect(x, y, w, h, fill, stroke=INK, stroke_width=sw, rx=3)
		if margin:
			d.line(x + 16, y + 6, x + 16, y + h - 6, "#e88a8a", 1.6)
		glyphs(d, x + (22 if margin else 12), y + 12, w - (32 if margin else 24), h - 24, rows, SCRIBBLE, rng, 1.8)


def pen(d, x1, y1, x2, y2, chewed, w=9.0):
	"""A pen from (x1, y1) to the writing end (x2, y2): black; a new one has a gold band and clip, a chewed one a pale
	gnawed end at (x1, y1)."""
	d.line(x1, y1, x2, y2, INK, w + 4)
	d.line(x1, y1, x2, y2, PEN, w)
	ang = math.atan2(y2 - y1, x2 - x1)
	ux, uy = math.cos(ang), math.sin(ang)
	d.line(x1 + ux * 6, y1 + uy * 6 - w * 0.25, x2 - ux * 10, y2 - uy * 10 - w * 0.25, "#5a5a66", 2, opacity=0.8)
	d.path("M%s %s L%s %s L%s %s Z" % P(x2 + uy * w * 0.45, y2 - ux * w * 0.45, x2 + ux * 12, y2 + uy * 12, x2 - uy * w * 0.45, y2 + ux * w * 0.45),
		GOLD, stroke=INK, stroke_width=2)
	if not chewed:
		bx, by = x1 + ux * 22, y1 + uy * 22
		d.line(bx, by, bx + ux * 5, by + uy * 5, GOLD, w + 1)
		d.line(x1 + ux * 6 - uy * (w * 0.55), y1 + uy * 6 + ux * (w * 0.55), x1 + ux * 34 - uy * (w * 0.55), y1 + uy * 34 + ux * (w * 0.55), GOLD, 3)
	else:
		d.circle(x1, y1, w * 0.9, CHEW, stroke=INK, stroke_width=2.2)
		for k in range(5):
			a = ang + math.pi + (k - 2) * 0.45
			d.line(x1, y1, x1 + math.cos(a) * w * 1.5, y1 + math.sin(a) * w * 1.5, CHEW, 2.6)
		for k in range(3):
			cx, cy = x1 + ux * (8 + k * 5), y1 + uy * (8 + k * 5)
			d.line(cx - uy * w * 0.5, cy + ux * w * 0.5, cx + uy * w * 0.5, cy - ux * w * 0.5, "#8a7050", 1.6)


def book(d, x, y, w, h, cover, rot=0.0, motif=None):
	with G(d, transform="rotate(%s %s %s)" % P(rot, x + w / 2, y + h / 2)):
		d.rect(x + 6, y + 6, w, h, dark(cover, 0.45), rx=4)
		d.rect(x + w - 4, y + 4, 8, h - 4, "#f4efe0", stroke=INK, stroke_width=2)
		d.rect(x, y, w, h, cover, stroke=INK, stroke_width=OL, rx=4)
		d.rect(x, y, 12, h, dark(cover, 0.25), rx=3)
		if motif:
			motif(x + w / 2 + 4, y + h / 2)


def clock_face(d, cx, cy, r, hh, mm, case=WOOD_D, crack=False):
	d.circle(cx, cy, r + 7, case, stroke=INK, stroke_width=OL)
	d.circle(cx, cy, r, "#fbf6e6", stroke=GOLD_D, stroke_width=3)
	for k in range(12):
		a = math.radians(k * 30 - 90)
		r1 = r - (9 if k % 3 == 0 else 6)
		d.line(cx + math.cos(a) * r1, cy + math.sin(a) * r1, cx + math.cos(a) * (r - 3), cy + math.sin(a) * (r - 3), "#3a3040", 2.2)
	ah = math.radians((hh % 12 + mm / 60.0) * 30 - 90)
	am = math.radians(mm * 6 - 90)
	d.line(cx, cy, cx + math.cos(ah) * r * 0.5, cy + math.sin(ah) * r * 0.5, INK, 4.5)
	d.line(cx, cy, cx + math.cos(am) * r * 0.78, cy + math.sin(am) * r * 0.78, INK, 3)
	d.circle(cx, cy, 3.5, INK)
	if crack:
		d.spath("M%s %s l10 8 l-4 10 l12 6 l2 12" % P(cx - r * 0.6, cy - r * 0.5), "#ffffff", 2.4, opacity=0.9)
		d.spath("M%s %s l-8 10 l6 8" % P(cx + r * 0.2, cy - r * 0.7), "#ffffff", 2, opacity=0.8)


def dust_patch(d, x, y, w, h, seed=3, col=DUST):
	rng = random.Random(seed)
	pts = B.blob_pts(x + w / 2, y + h / 2, w / 2, h / 2, rng, 11, 0.12)
	d.path(smooth(pts), col, opacity=0.95)
	for _ in range(22):
		d.circle(x + rng.uniform(0, w), y + rng.uniform(0, h), rng.uniform(0.8, 2.0), "#ffffff", opacity=0.7)


def tin(d, cx, cy, r, h, body, lid, rot=0.0):
	"""A round tin seen a little from above; returns the lid's centre."""
	with G(d, transform="rotate(%s %s %s)" % P(rot, cx, cy)):
		d.path("M%s %s L%s %s A%s %s 0 0 0 %s %s L%s %s Z" % P(cx - r, cy, cx - r, cy + h, r, r * 0.35, cx + r, cy + h, cx + r, cy),
			body, stroke=INK, stroke_width=OL, stroke_linejoin="round")
		d.ellipse(cx, cy, r, r * 0.35, lid, stroke=INK, stroke_width=OL)
	return cx, cy


def bandage_paw(d, x, y, s=1.0):
	with G(d, transform=T(x, y, s)):
		d.path("M-34 30 Q-40 -10 -20 -34 Q0 -48 22 -34 Q40 -10 34 30 Z", "#a8703e", stroke=INK, stroke_width=4)
		for k, (px, py) in enumerate([(-22, -40), (-6, -48), (10, -46), (24, -36)]):
			d.ellipse(px, py, 8, 10, "#8a5a30", stroke=INK, stroke_width=3)
		d.rect(-36, -14, 72, 30, "#f4f1e6", stroke=INK, stroke_width=3.5, rx=6)
		d.spath("M-30 -6 L30 -2 M-30 6 L30 10", "#c8ccd0", 2.2)
		d.circle(14, 0, 4, "#9a2a22", opacity=0.75)


def ledger_page_icon(d, seed, doodle=None, torn_bottom=False):
	rng = random.Random(seed)
	ishadow(d, 100, 186, 66, 8)
	with G(d, transform="rotate(%s 100 100)" % fm(rng.uniform(-8, 8))):
		edge = "M44 22 L156 22 L156 168 L44 168 Z" if not torn_bottom else \
			"M44 22 L156 22 L156 132 L146 140 L134 130 L120 142 L104 132 L90 144 L76 134 L60 142 L44 134 Z"
		d.path(edge, PAPER, stroke=INK, stroke_width=OL, stroke_linejoin="round")
		d.path("M44 22 Q38 60 44 100 Q40 140 44 168" if not torn_bottom else "M44 22 Q38 60 44 100 L44 134", "none",
			stroke="#d8cfbc", stroke_width=6)
		glyphs(d, 58, 34, 84, 54, 4, "#7a7064", rng, 1.6)
		if not torn_bottom:
			d.rect(58, 104, 70, 12, "#14141a", rx=2)
			d.rect(58, 122, 46, 12, "#14141a", rx=2)
		if doodle:
			doodle()


# --------------------------------------------------------------------------------------
# the icons
# --------------------------------------------------------------------------------------

def clue_rules3(d):
	rng = random.Random(301)
	ishadow(d)
	with G(d, transform="rotate(-5 100 100)"):
		d.rect(40, 18, 120, 164, "#e8d6b0", rx=8, stroke=INK, stroke_width=OL)
		d.rect(46, 24, 108, 152, "#fbf1dc", rx=5)
		d.rect(46, 24, 108, 36, GREEN, rx=5)
		snapjaw_crest(d, 100, 42, 0.3)
		cols = ["#e8553d", YUZU, "#2bb7b3", "#9a6aff", "#e8553d", "#3a7aa8", "#7cb342", "#c0392b"]
		for i in range(8):
			y = 70 + i * 13
			d.circle(56, y, 4, cols[i], stroke=INK, stroke_width=1.4)
			glyphs(d, 64, y - 5, 80 - (i % 3) * 8, 10, 1, SCRIBBLE, rng, 1.6)


def clue_snapjaw_file3(d):
	ishadow(d)
	d.path("M30 52 L80 52 L90 40 L150 40 Q158 40 158 48 L158 64 Z", "#c9963a", stroke=INK, stroke_width=OL, stroke_linejoin="round")
	with G(d, transform="rotate(5 110 90)"):
		d.rect(58, 30, 100, 120, PAPER, stroke=INK, stroke_width=3)
		# the drawing of a bookcase that takes up the rest of the page
		d.path("M76 136 L96 52 L138 60 L118 144 Z", WOOD, stroke=INK, stroke_width=3)
		for k in range(4):
			d.line(92 - k * 4, 70 + k * 18, 132 - k * 4, 78 + k * 18, INK, 2.2)
	d.path("M26 60 L162 60 Q170 60 168 68 L156 170 Q155 176 148 176 L36 176 Q30 176 29 170 L20 68 Q19 60 26 60 Z",
		d.vlin(60, 176, [(0, "#f2c66a"), (1, "#d8a040")]), stroke=INK, stroke_width=OL, stroke_linejoin="round")
	snapjaw_crest(d, 70, 130, 0.36)
	d.circle(140, 132, 12, "#c0392b", stroke=INK, stroke_width=2.5)
	d.rect(134, 126, 12, 12, "#ffe0d0", rx=2)


def clue_ledger_read(d):
	rng = random.Random(303)
	ishadow(d, 100, 184, 80, 9)
	d.path("M14 150 L100 166 L186 150 L186 54 L100 70 L14 54 Z", "#1c1a22", stroke=INK, stroke_width=OL, stroke_linejoin="round")
	d.path("M22 146 L98 160 L98 70 L22 58 Z", PAPER, stroke=INK, stroke_width=2.5)
	d.path("M102 160 L178 146 L178 58 L102 70 Z", PAPER, stroke=INK, stroke_width=2.5)
	for k in range(4):
		y = 82 + k * 18
		glyphs(d, 30, y - 6, 60, 8, 1, "#8a8070", rng, 1.4)
		d.rect(108, y - 2, 52 - (k % 2) * 12, 8, "#14141a", rx=1.5)
	d.rect(92, 40, 16, 30, BRASS, stroke=INK, stroke_width=2.5, rx=3)


def clue_bat_bite(d):
	ishadow(d, 100, 186, 62, 8)
	bandage_paw(d, 100, 122, 1.3)
	# an 'improved' bat overhead, one red eye
	with G(d, transform=T(100, 44, 1.0)):
		d.path("M0 6 Q-20 -10 -52 -4 Q-42 4 -46 14 Q-30 8 -24 18 Q-12 10 0 16 Q12 10 24 18 Q30 8 46 14 Q42 4 52 -4 Q20 -10 0 6 Z",
			"#2a2230", stroke=INK, stroke_width=3)
		d.circle(0, 4, 9, "#3a3040", stroke=INK, stroke_width=2.5)
		d.circle(-3, 2, 2.4, "#ff3b3b")
		d.circle(4, 2, 2.4, "#c8ccd0")


def clue_grub_soup(d):
	ishadow(d, 100, 186, 74, 9)
	d.path("M34 96 L166 96 L158 168 Q156 176 148 176 L52 176 Q44 176 42 168 Z", "#3a3a44", stroke=INK, stroke_width=OL)
	d.ellipse(100, 96, 66, 14, "#d89040", stroke=INK, stroke_width=OL)
	d.ellipse(100, 98, 58, 9, "#e8a858")
	for x in (28, 172):
		d.rect(x - 10, 104, 20, 10, "#3a3a44", stroke=INK, stroke_width=3, rx=4)
	# the ladle, shaking
	with G(d, transform="rotate(-24 120 60)"):
		d.line(118, 20, 118, 92, INK, 9)
		d.line(118, 20, 118, 92, SILVER, 5)
		d.ellipse(118, 96, 16, 9, SILVER, stroke=INK, stroke_width=3)
	for k in range(3):
		d.spath("M%s %s q-6 6 0 12" % P(150 + k * 9, 30 + k * 4), INK, 3)
	for k in range(3):
		d.spath("M%s %s q-12 -10 -6 -24" % P(78 - k * 10, 86), "#ffffff", 3, opacity=0.5)


def clue_fallen_bookcase(d):
	ishadow(d, 100, 184, 84, 9)
	d.rect(20, 120, 120, 20, OAK, stroke=INK, stroke_width=OL)
	d.rect(28, 140, 14, 36, OAK, stroke=INK, stroke_width=3.5)
	d.rect(118, 140, 14, 36, OAK, stroke=INK, stroke_width=3.5)
	with G(d, transform="rotate(-38 168 172)"):
		d.rect(150, 40, 46, 132, WOOD, stroke=INK, stroke_width=OL)
		for k in range(5):
			d.line(150, 64 + k * 24, 196, 64 + k * 24, INK, 3)
		for k in range(5):
			d.rect(156, 46 + k * 24, 6 + k % 2 * 3, 16, ["#c0392b", "#3a7aa8", "#7cb342", YUZU, "#9a6aff"][k], stroke=INK, stroke_width=1.5)
	# the base walked out from the wall: two pale scrapes on the boards
	d.spath("M176 184 L196 160 M186 186 L200 168", "#f0d8b0", 4)


def clue_wall_anchor(d):
	ishadow(d, 100, 186, 70, 8)
	d.rect(16, 16, 168, 164, "#2f5e48", stroke=INK, stroke_width=OL, rx=6)
	for k in range(4):
		d.path("M%s 40 l8 10 l-8 10 l-8 -10 Z" % fm(40 + k * 40), "#3f7458", opacity=0.8)
	# the cornice ledge with six screws in a row, under white dust
	d.rect(10, 22, 180, 22, WOOD_D, stroke=INK, stroke_width=3.5)
	for k in range(6):
		d.rect(48 + k * 18, 15, 5, 12, SILVER, stroke=INK, stroke_width=1.6)
		d.rect(45 + k * 18, 13, 11, 4, SILVER_D, stroke=INK, stroke_width=1.4)
	d.path("M40 16 Q100 10 160 16 L160 22 L40 22 Z", "#ffffff", opacity=0.8)
	# the plate's outline and two clean holes
	d.rect(70, 92, 60, 40, "#4a8a68", stroke="#24402f", stroke_width=2.5, stroke_dasharray="6 4")
	for x in (84, 116):
		d.circle(x, 112, 6, "#14100c", stroke=INK, stroke_width=2)


def clue_cup_ring(d):
	ishadow(d, 100, 186, 78, 9)
	d.path("M16 112 L100 70 L184 112 L100 156 Z", WOOD_L, stroke=INK, stroke_width=OL, stroke_linejoin="round")
	d.path("M16 112 L100 156 L100 172 L16 128 Z", WOOD_D, stroke=INK, stroke_width=3.5)
	d.path("M184 112 L100 156 L100 172 L184 128 Z", WOOD, stroke=INK, stroke_width=3.5)
	d.path("M30 112 L100 78 L170 112 L100 148 Z", DUST, opacity=0.95)
	d.ellipse(104, 116, 20, 10, "none", stroke=WOOD_D, stroke_width=4.5)
	d.ellipse(104, 116, 14, 6, DUST)
	# a corner of the pen box
	d.path("M52 102 L84 86 L98 94 L66 110 Z", "#1f3a66", stroke=INK, stroke_width=2.5)
	for k in range(5):
		d.line(60 + k * 6, 104 - k * 3, 74 + k * 6, 98 - k * 3 - 6, PEN, 2.6)


def clue_desk_contents(d):
	ishadow(d, 100, 186, 84, 9)
	d.path("M10 104 L190 104 L178 150 L22 150 Z", OAK, stroke=INK, stroke_width=OL, stroke_linejoin="round")
	d.path("M40 108 L120 108 L116 134 L44 134 Z", "#3a6a4a", stroke=INK, stroke_width=2.5)
	# lamp, books, spectacles, inkstand
	d.line(150, 104, 150, 62, INK, 7)
	d.line(150, 104, 150, 62, BRASS, 3)
	d.path("M132 64 Q150 36 168 64 Z", "#2f7a4c", stroke=INK, stroke_width=3)
	glow(d, 150, 70, 26, YUZU, 0.45)
	for k, c in enumerate(["#c0392b", "#3a7aa8", "#e8b040"]):
		d.rect(16, 88 - k * 10, 40, 10, c, stroke=INK, stroke_width=2.2)
	for x in (82, 100):
		d.circle(x, 120, 8, "none", stroke=INK, stroke_width=3)
	d.line(90, 120, 92, 120, INK, 3)
	d.rect(118, 116, 24, 10, BRASS, stroke=INK, stroke_width=2)
	# and on the floor, well away from it, one pen
	pen(d, 120, 178, 172, 168, False, 7)


def clue_nibs_blotter(d):
	rng = random.Random(310)
	ishadow(d, 100, 184, 80, 9)
	d.path("M20 60 L180 50 L188 150 L14 162 Z", "#3a7a54", stroke=INK, stroke_width=OL, stroke_linejoin="round")
	for x0, x1 in ((20, 34), (166, 180)):
		d.path("M%s 60 L%s 58 L%s 158 L%s 160 Z" % P(x0, x1, x1 + 2, x0 - 4), "#6a2a1e", stroke=INK, stroke_width=2.5)
	# mirror writing that soaked through: scribbles, mirrored
	with G(d, transform="translate(200 0) scale(-1 1)"):
		glyphs(d, 44, 72, 110, 70, 6, "#1e3a5a", rng, 2.0, a=0.8)
	d.path("M120 110 Q150 96 170 122 Q150 140 120 128 Z", "#ffffff", opacity=0.18)


def clue_arm_no_bruise(d):
	ishadow(d, 100, 186, 74, 8)
	# a white coat sleeve across a desk edge, bent where an arm doesn't bend; fur flat, no swelling
	d.rect(10, 128, 180, 22, OAK, stroke=INK, stroke_width=3.5)
	d.path("M14 120 L92 104 L104 124 L22 140 Z", "#f4f4f0", stroke=INK, stroke_width=OL, stroke_linejoin="round")
	d.path("M92 104 L150 84 L160 104 L104 124 Z", "#f4f4f0", stroke=INK, stroke_width=OL, stroke_linejoin="round")
	d.path("M150 84 Q176 78 182 94 Q178 108 160 104 Z", "#b08050", stroke=INK, stroke_width=3.5)
	d.spath("M96 100 L102 108 L94 114 L104 122", "#c8ccd8", 2.4)
	d.spath("M36 116 L84 106 M110 112 L150 98", "#dde4ee", 2.2)
	d.path("M60 40 L180 40 L188 60 L52 60 Z", WOOD, stroke=INK, stroke_width=3.5)


def clue_nibs_mouth(d):
	ishadow(d, 100, 186, 66, 8)
	d.ellipse(100, 92, 76, 58, "#a8784a", stroke=INK, stroke_width=OL)
	d.ellipse(100, 114, 52, 30, "#8a5c34", stroke=INK, stroke_width=3)
	d.ellipse(74, 78, 7, 5, INK)
	d.ellipse(126, 78, 7, 5, INK)
	# front teeth stained dark, a dark tongue
	d.rect(88, 118, 11, 22, "#3a3236", stroke=INK, stroke_width=2.5, rx=2)
	d.rect(101, 118, 11, 22, "#2a2428", stroke=INK, stroke_width=2.5, rx=2)
	d.path("M84 140 Q100 156 116 140 Q100 148 84 140 Z", "#3a2a30", stroke=INK, stroke_width=2.5)
	d.spath("M90 122 L90 136", "#6a6266", 1.6)


def clue_door_scratches(d):
	ishadow(d, 100, 186, 66, 8)
	d.rect(36, 10, 128, 172, OAK, stroke=INK, stroke_width=OL)
	d.rect(52, 24, 96, 60, dark(OAK, 0.2), stroke=INK, stroke_width=3)
	d.rect(52, 96, 96, 60, dark(OAK, 0.2), stroke=INK, stroke_width=3)
	d.circle(146, 96, 6, BRASS, stroke=INK, stroke_width=2)
	# rows of four, low down
	for gx, gy in ((60, 132), (98, 140), (78, 156), (116, 152)):
		for k in range(4):
			d.line(gx + k * 6, gy, gx + k * 6 + 4, gy + 20, "#f2d6a8", 2.6)
	for x in (68, 92, 118, 136):
		d.spath("M%s 186 q4 -6 8 0" % fm(x), "#d8a868", 2.2)


def clue_tray_grains(d):
	ishadow(d, 100, 186, 80, 9)
	d.path("M14 136 L186 136 L174 166 L26 166 Z", SILVER, stroke=INK, stroke_width=OL, stroke_linejoin="round")
	d.path("M60 140 Q56 72 100 70 Q144 72 140 140 Z", "#f4f1ea", stroke=INK, stroke_width=OL)
	d.path("M138 100 Q170 96 176 70", "none", stroke=INK, stroke_width=8)
	d.path("M138 100 Q170 96 176 70", "none", stroke="#f4f1ea", stroke_width=4)
	d.path("M64 92 Q40 92 44 116 Q50 128 62 122", "none", stroke=INK, stroke_width=7)
	d.ellipse(100, 70, 26, 7, "#e8e4da", stroke=INK, stroke_width=3)
	d.rect(152, 118, 22, 20, "#f4f1ea", stroke=INK, stroke_width=3, rx=4)
	rng = random.Random(314)
	for _ in range(16):
		d.circle(30 + rng.uniform(0, 30), 146 + rng.uniform(0, 12), rng.uniform(1.4, 2.6), "#fbf8f0", stroke="#9a958c", stroke_width=0.8)
	d.ellipse(46, 150, 12, 5, "none", stroke="#9a958c", stroke_width=1.6, stroke_dasharray="3 2")


def clue_bell_tape(d):
	ishadow(d, 100, 186, 60, 8)
	d.rect(70, 10, 60, 50, WOOD_D, stroke=INK, stroke_width=3.5, rx=4)
	d.path("M80 62 Q100 22 120 62 Z", BRASS, stroke=INK, stroke_width=OL)
	d.circle(100, 66, 6, BRASS_D, stroke=INK, stroke_width=2.5)
	d.path("M86 76 L114 76 L120 182 L80 182 Z", PAPER, stroke=INK, stroke_width=3.5)
	d.line(84, 100, 116, 100, "#c8c0b0", 1.4)
	d.line(84, 130, 116, 130, "#c8c0b0", 1.4)
	d.line(84, 160, 116, 160, "#c8c0b0", 1.4)
	d.circle(100, 116, 4.5, "#14100c")
	sparkle(d, 136, 56, 7, "#ffffff", 0.9)


def clue_pantry_glitter(d):
	ishadow(d, 100, 186, 50, 7)
	for x in (82, 112):
		d.line(x, 6, x + 4, 194, INK, 14)
		d.line(x, 6, x + 4, 194, "#c8a86a", 9)
		for y in range(14, 190, 14):
			d.line(x - 3, y, x + 4, y + 8, "#8a6a3a", 2.2)
	rng = random.Random(316)
	for _ in range(22):
		x = 84 + rng.uniform(-6, 10)
		y = 92 + rng.uniform(0, 40)
		d.circle(x, y, rng.uniform(1.6, 3.4), PINK, stroke="#ffffff", stroke_width=0.7)
	sparkle(d, 104, 88, 9, "#ffffff", 1.0, glow_c=PINK)


def clue_old_puddle(d):
	rng = random.Random(317)
	ishadow(d, 100, 186, 82, 9)
	with G(d, transform="rotate(-6 100 100)"):
		d.rect(16, 30, 168, 140, "#ece6d4", stroke=INK, stroke_width=OL)
		d.rect(28, 40, 144, 24, "#3a3a40")
		for c in range(3):
			glyphs(d, 30 + c * 48, 74, 40, 84, 7, "#6a6458", rng, 1.4)
		d.circle(150, 140, 18, "none", stroke="#c8b070", stroke_width=5, opacity=0.6)
	# a loupe over one small e with a nick out of its top
	d.circle(120, 104, 40, "#ffffff", opacity=0.6)
	d.circle(120, 104, 40, "none", stroke=INK, stroke_width=6)
	d.line(148, 132, 180, 168, INK, 12)
	d.line(148, 132, 180, 168, WOOD, 7)
	d.path("M104 104 L136 104 Q136 84 120 84 Q102 84 102 104 Q102 124 122 124 Q132 124 136 116", "none", stroke=INK, stroke_width=6)
	d.rect(108, 80, 10, 8, "#ffffff")


def _manual(d, seed, motif, fold=False):
	ishadow(d, 100, 186, 70, 8)
	book(d, 36, 22, 124, 158, "#2a6a6a", -4, motif)
	if fold:
		d.path("M150 24 L162 24 L162 38 Z", PAPER, stroke=INK, stroke_width=2.5, transform="rotate(-4 100 100)")
	d.path("M70 30 L82 30 L82 50 L76 44 L70 50 Z", "#c0392b", transform="rotate(-4 100 100)")


def clue_manual_injuries(d):
	def bone(x, y):
		with G(d, transform=T(x, y, 1.0, -30)):
			d.rect(-26, -6, 52, 12, "#f4efe0", stroke=INK, stroke_width=3, rx=5)
			for sx in (-26, 26):
				for sy in (-7, 7):
					d.circle(sx, sy, 8, "#f4efe0", stroke=INK, stroke_width=3)
			d.rect(-24, -4, 48, 8, "#f4efe0")
			d.spath("M-2 -6 L3 0 L-3 6", INK, 2.4)
	_manual(d, 318, bone)


def clue_manual_illness(d):
	def bat(x, y):
		with G(d, transform=T(x, y, 0.8)):
			d.path("M0 6 Q-20 -10 -52 -4 Q-42 4 -46 14 Q-30 8 -24 18 Q-12 10 0 16 Q12 10 24 18 Q30 8 46 14 Q42 4 52 -4 Q20 -10 0 6 Z",
				"#f4efe0", stroke=INK, stroke_width=3)
		d.path("M%s %s q-8 10 0 20 q8 -10 0 -20 Z" % P(x, y + 22), "#9fd8f0", stroke=INK, stroke_width=2)
		d.line(x - 14, y + 18, x + 14, y + 46, "#c0392b", 4)
	_manual(d, 319, bat, True)


def clue_powder_record(d):
	rng = random.Random(320)
	ishadow(d, 100, 186, 66, 8)
	d.rect(24, 16, 152, 166, "#e8eef0", stroke=INK, stroke_width=OL, rx=6)
	with G(d, transform="rotate(4 100 100)"):
		d.rect(40, 36, 120, 128, PAPER, stroke=INK, stroke_width=3)
		for k in range(4):
			y = 58 + k * 26
			for j in range(k + 1):
				d.circle(56 + j * 12, y, 4.5, "#ffffff", stroke=INK, stroke_width=1.8)
			glyphs(d, 108, y - 6, 44, 12, 1, SCRIBBLE, rng, 1.6)
		d.line(50, 140, 150, 140, "#c0392b", 3)
	for x, y, r in ((44, 30, -20), (156, 30, 20)):
		d.rect(x - 14, y - 6, 28, 12, "#e8dca0", opacity=0.85, transform="rotate(%s %s %s)" % P(r, x, y))


def clue_lulu_tin(d):
	ishadow(d, 100, 186, 66, 8)
	d.path("M40 104 L40 156 A60 20 0 0 0 160 156 L160 104 Z", SILVER, stroke=INK, stroke_width=OL)
	d.ellipse(100, 104, 60, 20, "#f4f1ec", stroke=INK, stroke_width=OL)
	d.ellipse(84, 104, 8, 3.5, "#c8c4bc")
	d.ellipse(104, 106, 8, 3.5, "#c8c4bc")
	# the lid leaning against it, a V on it, a fleck of pink
	with G(d, transform="rotate(-24 150 64)"):
		d.ellipse(150, 64, 46, 16, SILVER, stroke=INK, stroke_width=OL)
		d.spath("M136 58 L150 72 L164 58", INK, 4)
	sparkle(d, 160, 54, 7, "#ffffff", 1.0, glow_c=PINK)
	d.circle(158, 58, 3.5, PINK, stroke="#ffffff", stroke_width=0.8)


def clue_bait_tin(d):
	ishadow(d, 100, 186, 70, 8)
	tin(d, 100, 80, 64, 76, "#c0392b", "#e8553d")
	d.rect(36, 108, 128, 40, "#f2e2b0", stroke=INK, stroke_width=3)
	# a grinning cartoon rat, crosses for eyes
	with G(d, transform=T(100, 76, 1.0)):
		d.ellipse(0, 0, 30, 14, "#9a9aa4", stroke=INK, stroke_width=3)
		for sx in (-1, 1):
			d.circle(sx * 22, -10, 8, "#9a9aa4", stroke=INK, stroke_width=3)
			d.spath("M%s -4 l6 6 M%s 2 l6 -6" % P(sx * 10 - 3, sx * 10 - 3), INK, 2.4)
		d.spath("M-8 6 Q0 12 8 6", INK, 2.4)
	snapjaw_crest(d, 100, 128, 0.24, ring=False)
	d.spath("M150 30 q8 -8 0 -16 q-8 -8 0 -16", "#8a7a2a", 3, opacity=0.7)


def clue_generator_log(d):
	rng = random.Random(323)
	ishadow(d, 100, 186, 70, 8)
	d.circle(100, 12, 6, SILVER, stroke=INK, stroke_width=2.5)
	d.rect(30, 20, 140, 162, "#e8d6b0", stroke=INK, stroke_width=OL, rx=4)
	d.rect(40, 30, 120, 142, PAPER)
	d.rect(46, 38, 30, 14, INK, rx=2)
	for k in range(6):
		d.spath("M54 %s l6 6 l10 -12" % fm(66 + k * 14), "#2a6a3a", 3)
	d.line(46, 152, 154, 152, "#c0392b", 2.4)
	glyphs(d, 86, 144, 64, 10, 1, SCRIBBLE, rng, 1.8)
	d.spath("M86 166 q10 -12 20 0 t20 0 t20 0", "#24306a", 2.6)
	d.line(100, 12, 70, 34, "#a8a8a8", 1.6)


def clue_fitting_ticket(d):
	rng = random.Random(324)
	ishadow(d, 100, 186, 64, 8)
	d.path("M60 30 Q100 14 140 30 L150 100 Q160 150 150 178 L50 178 Q40 150 50 100 Z", "#f0c8e0", stroke=INK, stroke_width=OL)
	d.path("M60 30 Q100 14 140 30 L134 60 Q100 70 66 60 Z", LILAC, stroke=INK, stroke_width=3)
	for k in range(6):
		d.line(56 + k * 9, 168, 56 + k * 9, 158, SILVER_D, 2)
		d.circle(56 + k * 9, 157, 2.2, "#c0392b")
	for k in range(6):
		x = 112 + k * 6 + rng.uniform(-2, 2)
		d.line(x, 172, x + rng.uniform(-6, 6), 160, SILVER_D, 2)
		d.circle(x, 159, 2.2, "#c0392b")
	with G(d, transform="rotate(-10 124 96)"):
		d.rect(98, 78, 56, 36, "#e8d6b0", stroke=INK, stroke_width=3)
		glyphs(d, 104, 84, 44, 24, 2, SCRIBBLE, rng, 1.6)
	d.circle(108, 82, 3, "#c0392b")


def clue_passage_door(d):
	ishadow(d, 100, 186, 70, 8)
	d.rect(16, 10, 168, 176, "#4a6a58", stroke=INK, stroke_width=OL)
	d.rect(16, 120, 168, 66, WOOD_D, stroke=INK, stroke_width=3)
	d.rect(76, 30, 48, 156, "#10100e", stroke=INK, stroke_width=3.5)
	with G(d, transform="rotate(-8 76 108)"):
		d.rect(48, 30, 30, 152, WOOD, stroke=INK, stroke_width=3.5)
		d.circle(70, 106, 6, "none", stroke=BRASS, stroke_width=3)
	d.path("M80 186 L120 186 L116 150 Q100 144 84 150 Z", DUST, opacity=0.95)
	# Bruno-sized, it isn't: arrows that won't meet
	d.spath("M30 60 L66 60 M134 60 L170 60", "#ffe08a", 3, stroke_dasharray="6 4")


def clue_passage_tracks(d):
	ishadow(d, 100, 186, 82, 9)
	d.path("M20 40 L180 40 L196 186 L4 186 Z", GREY_DUST, stroke=INK, stroke_width=OL)
	d.path("M26 46 L174 46 L188 180 L12 180 Z", DUST)
	for k in range(4):
		for side in (-1, 1):
			x = 100 + side * 20 + (k % 2) * side * 4
			y = 60 + k * 32
			d.ellipse(x, y, 9, 13, GREY_DUST, stroke="#7a756c", stroke_width=1.4)
			for t in range(3):
				d.circle(x - 6 + t * 6, y - 14, 3, GREY_DUST)


def clue_shawl_hem(d):
	ishadow(d, 100, 186, 82, 9)
	d.path("M20 40 L180 40 L196 186 L4 186 Z", GREY_DUST, stroke=INK, stroke_width=OL)
	d.path("M26 46 L174 46 L188 180 L12 180 Z", DUST)
	d.path("M60 46 Q80 110 70 180 L116 180 Q122 110 96 46 Z", "#b8b2a8", opacity=0.9)
	d.rect(150, 100, 34, 80, WOOD_D, stroke=INK, stroke_width=3)
	d.path("M150 128 L140 118 L152 122 Z", WOOD_L, stroke=INK, stroke_width=1.6)
	for k in range(3):
		d.spath("M146 %s q-16 6 -28 -2" % fm(120 + k * 4), LILAC_D, 2.4)


def clue_hat_feather(d):
	ishadow(d, 100, 186, 60, 8)
	d.rect(14, 26, 30, 30, "#3a3a40", stroke=INK, stroke_width=3.5)
	d.path("M44 36 L120 36 L120 46 L44 46 Z", "#3a3a40", stroke=INK, stroke_width=3.5)
	d.path("M120 36 L132 26 L134 32 L124 46 Z", "#3a3a40", stroke=INK, stroke_width=3)
	# a long lilac plume caught on it, snapped
	d.path("M118 42 Q96 80 104 128 Q86 96 98 46 Z", LILAC, stroke=INK, stroke_width=3)
	for k in range(7):
		y = 56 + k * 10
		d.spath("M%s %s q-18 4 -26 14 M%s %s q16 6 20 18" % P(101, y, 103, y), LILAC_D, 2)
	d.path("M120 150 Q130 170 116 188 Q138 172 132 148 Z", LILAC, stroke=INK, stroke_width=3)
	d.spath("M104 128 l4 6 l-6 2 l4 6", INK, 2.4)


def clue_pen_case(d):
	ishadow(d, 100, 186, 80, 9)
	d.path("M16 96 L184 96 L176 162 L24 162 Z", WOOD, stroke=INK, stroke_width=OL, stroke_linejoin="round")
	d.path("M26 104 L174 104 L168 152 L32 152 Z", "#8e1f2a", stroke=INK, stroke_width=2.5)
	d.path("M16 96 L30 34 L170 34 L184 96 Z", WOOD_D, stroke=INK, stroke_width=OL, stroke_linejoin="round")
	d.rect(70, 50, 60, 20, PAPER, stroke=INK, stroke_width=2)
	glyphs(d, 76, 54, 48, 12, 1, SCRIBBLE, random.Random(329), 1.6)
	for k in range(6):
		x = 44 + k * 22
		pen(d, x + 6, 112, x - 2, 146, True, 6)


def clue_shaft_pen(d):
	ishadow(d, 100, 186, 80, 9)
	d.path("M10 120 Q60 96 110 112 Q160 96 190 118 L190 180 L10 180 Z", "#2a221c", stroke=INK, stroke_width=OL)
	rng = random.Random(330)
	for _ in range(14):
		d.circle(20 + rng.uniform(0, 160), 130 + rng.uniform(0, 44), rng.uniform(3, 7), "#3a3028", opacity=0.9)
	d.rect(124, 140, 26, 8, SILVER_D, rx=3, transform="rotate(-20 136 144)")
	pen(d, 52, 108, 148, 128, True, 9)
	for k in range(3):
		d.spath("M%s 94 q-8 -10 0 -20 q8 -10 0 -20" % fm(70 + k * 30), "#7a8a4a", 2.6, opacity=0.6)


def clue_gallery_clock(d):
	ishadow(d, 100, 186, 76, 9)
	d.rect(14, 150, 172, 30, "#c8c4bc", stroke=INK, stroke_width=3.5)
	with G(d, transform="rotate(-14 100 104)"):
		d.path("M50 160 L50 90 Q50 44 100 44 Q150 44 150 90 L150 160 Z", WOOD_D, stroke=INK, stroke_width=OL)
		d.rect(40, 156, 120, 12, BRASS, stroke=INK, stroke_width=3)
		clock_face(d, 100, 98, 36, 11, 5, WOOD_D, True)


def clue_dinner_sketch(d):
	ishadow(d, 100, 186, 84, 8)
	with G(d, transform="rotate(-4 100 100)"):
		d.rect(10, 56, 180, 96, "#f4efe2", stroke=INK, stroke_width=OL)
		for k in range(4):
			x = 18 + k * 44
			d.rect(x, 64, 38, 80, "none", stroke="#3a3a3a", stroke_width=2.5)
			d.circle(x + 19, 76, 7, "none", stroke="#3a3a3a", stroke_width=2)
			d.line(x + 19, 76, x + 19, 71, "#3a3a3a", 1.6)
			d.line(x + 19, 76, x + 22 + k, 78, "#3a3a3a", 1.6)
			d.line(x + 4, 120, x + 34, 120, "#3a3a3a", 2.4)
			for j in range(3):
				if j != k % 3:
					d.circle(x + 9 + j * 10, 112, 4.5, "#5a5a5a")
	d.rect(150, 154, 40, 8, "#2a2a2a", rx=3, transform="rotate(-30 170 158)")


def clue_photo_roll(d):
	ishadow(d, 100, 186, 82, 8)
	d.spath("M4 30 Q100 44 196 26", INK, 5)
	d.spath("M4 30 Q100 44 196 26", "#e8dcc0", 2.4)
	for k, (x, rot) in enumerate(((16, -4), (72, 2), (128, -2))):
		with G(d, transform="rotate(%s %s 100)" % P(rot, x + 26)):
			d.rect(x, 40, 54, 120, "#f4f2ec", stroke=INK, stroke_width=3.5)
			dark_frame = "#2a2a34" if k < 2 else "#0e0e14"
			d.rect(x + 5, 46, 44, 88, dark_frame)
			if k < 2:
				d.rect(x + 10, 60, 14, 22, "#c8a050", opacity=0.8)
				d.rect(x + 28, 68, 14, 30, "#5a4a3a", opacity=0.9)
			else:
				for j in range(9):
					d.circle(x + 10 + (j * 13) % 34, 54 + (j * 17) % 70, 1.8, "#ffffff")
			d.rect(x + 30, 124, 16, 6, STAMP)
		d.rect(x + 18, 32, 12, 18, "#d8a868", rx=2, stroke=INK, stroke_width=2)


def clue_gallery_grate(d):
	ishadow(d, 100, 186, 82, 9)
	d.rect(20, 40, 160, 140, "#e8e4dc", stroke=INK, stroke_width=OL)
	d.rect(44, 70, 112, 110, "#1a1614", stroke=INK, stroke_width=3)
	d.path("M52 176 Q60 130 100 132 Q140 128 150 176 Z", "#6a6662", stroke=INK, stroke_width=2.5)
	d.path("M60 170 Q76 146 104 150 Q130 144 142 170 Z", "#8a8680")
	for k in range(5):
		d.line(52 + k * 24, 150, 52 + k * 24, 180, "#3a3a40", 4)
	with G(d, transform="rotate(14 120 140)"):
		d.path("M104 128 L146 128 L146 152 L132 146 L120 154 L104 146 Z", PAPER, stroke=INK, stroke_width=2.5)
		for j in range(4):
			d.rect(110 + j * 8, 134, 5, 7, "#3a3a40")


def clue_nibs_cup(d):
	ishadow(d, 100, 186, 76, 9)
	d.path("M14 150 Q40 120 100 128 Q170 118 188 154 Q150 178 100 172 Q40 178 14 150 Z", LILAC, stroke=INK, stroke_width=OL)
	d.spath("M40 150 Q100 136 160 152", LILAC_D, 2.4)
	d.path("M64 140 L70 92 L134 92 L140 140 Q100 152 64 140 Z", "#fbf8f0", stroke=INK, stroke_width=OL)
	d.ellipse(102, 92, 32, 9, "#a8784a", stroke=INK, stroke_width=3)
	d.path("M136 104 Q160 104 156 124 Q150 134 136 128", "none", stroke=INK, stroke_width=7)
	d.path("M136 104 Q160 104 156 124 Q150 134 136 128", "none", stroke="#fbf8f0", stroke_width=3.5)
	for k in range(3):
		d.spath("M%s 78 q-8 -10 0 -22 q8 -10 0 -22" % fm(84 + k * 16), "#c8a8e0", 3, opacity=0.8)


def clue_nibs_sheet(d):
	rng = random.Random(336)
	ishadow(d, 100, 186, 66, 8)
	with G(d, transform="rotate(-5 100 100)"):
		d.rect(40, 16, 120, 166, PAPER, stroke=INK, stroke_width=OL)
		d.line(70, 20, 70, 178, "#e88a8a", 1.8)
		for k in range(8):
			y = 34 + k * 18
			d.rect(46, y - 4, 18, 8, "#24306a", rx=1.5)
			glyphs(d, 76, y - 6, 74 - (k % 3) * 10, 12, 1, "#24306a", rng, 1.6)
		d.spath("M76 168 q20 4 30 -2 q12 -6 30 6", "#24306a", 2.6, opacity=0.7)
	d.path("M150 10 Q186 12 182 44 L160 40 Z", LILAC, stroke=INK, stroke_width=2.5)


def clue_scene_photos(d):
	ishadow(d, 100, 186, 82, 9)
	for k, (dx, rot) in enumerate(((-8, -10), (6, 4), (0, -2))):
		with G(d, transform="rotate(%s 100 100)" % fm(rot)):
			x, y = 36 + dx, 34 + k * 4
			d.rect(x, y, 128, 100, "#f4f2ec", stroke=INK, stroke_width=3.5)
			d.rect(x + 7, y + 7, 114, 74, ["#3a2a26", "#2a3a30", "#4a3428"][k])
			if k == 2:
				d.rect(x + 20, y + 30, 26, 46, "#7a4a2c")
				d.circle(x + 80, y + 40, 14, "#a8784a")
				d.rect(x + 92, y + 66, 18, 8, STAMP)
	d.circle(168, 160, 22, "#2a2a30", stroke=INK, stroke_width=3.5)
	d.circle(168, 160, 9, "#5a5a66", stroke=INK, stroke_width=2)


def clue_packet_log(d):
	rng = random.Random(338)
	ishadow(d, 100, 186, 80, 9)
	d.rect(20, 20, 160, 116, "#1e1e24", stroke=INK, stroke_width=OL, rx=8)
	d.rect(30, 30, 140, 96, "#06140c")
	for k in range(9):
		w = rng.uniform(40, 120)
		d.rect(36, 36 + k * 10, w, 4, "#3fdc6a", opacity=0.85)
	d.rect(36, 126 - 8, 10, 4, "#3fdc6a")
	d.rect(84, 136, 32, 22, "#2a2a30", stroke=INK, stroke_width=3)
	d.rect(50, 156, 100, 14, "#3a3a44", stroke=INK, stroke_width=3, rx=4)
	for k in range(4):
		d.spath("M%s 170 q-6 10 4 20" % fm(30 + k * 10), ["#c0392b", "#2bb7b3", YUZU, "#7cb342"][k], 3)


def clue_conservatory_sketch(d):
	ishadow(d, 100, 186, 66, 8)
	d.line(60, 180, 90, 20, WOOD_D, 7)
	d.line(140, 180, 110, 20, WOOD_D, 7)
	d.rect(36, 30, 128, 104, "#f4efe2", stroke=INK, stroke_width=OL)
	for k, (x, y) in enumerate(((70, 64), (96, 56), (84, 86))):
		for j in range(5):
			a = math.radians(j * 72 + k * 20)
			d.ellipse(x + math.cos(a) * 8, y + math.sin(a) * 8, 7, 4, "none", stroke="#3a3a3a", stroke_width=1.8,
				transform="rotate(%s %s %s)" % P(math.degrees(a), x + math.cos(a) * 8, y + math.sin(a) * 8))
	d.path("M118 110 Q130 86 150 100 Q156 120 136 124 Q120 124 118 110 Z", "none", stroke="#3a3a3a", stroke_width=2.2)
	d.circle(138, 98, 7, "none", stroke="#3a3a3a", stroke_width=2)
	d.rect(52, 134, 96, 8, WOOD, stroke=INK, stroke_width=2.5)


def clue_watch_roster(d):
	rng = random.Random(340)
	ishadow(d, 100, 186, 64, 8)
	d.rect(40, 16, 120, 166, "#8a5a30", stroke=INK, stroke_width=OL, rx=6)
	d.rect(50, 30, 100, 144, PAPER, stroke=INK, stroke_width=2.5)
	d.rect(78, 10, 44, 22, SILVER, stroke=INK, stroke_width=3, rx=4)
	d.line(100, 40, 100, 168, "#c8c0b0", 1.6)
	for k in range(6):
		y = 48 + k * 20
		d.rect(56, y, 38, 8, "#24306a", rx=1.5)
		glyphs(d, 106, y - 3, 38, 12, 1, "#3a6aa8", rng, 1.6)
	d.line(150, 60, 182, 176, "#a8a8a8", 1.6)
	d.rect(178, 170, 6, 18, YUZU, stroke=INK, stroke_width=1.6)


def clue_terrace_mud(d):
	ishadow(d, 100, 186, 82, 9)
	d.path("M10 110 L190 110 L180 178 L20 178 Z", "#8a8a8a", stroke=INK, stroke_width=OL)
	d.rect(14, 96, 172, 20, "#a8a8a8", stroke=INK, stroke_width=3.5)
	d.path("M24 116 L176 116 L170 168 L30 168 Z", "#4a3826")
	for x in (70, 112):
		d.path("M%s 126 q14 0 14 14 l0 18 q0 6 -7 6 q-7 0 -7 -6 l0 -18 q-14 0 -14 -14 Z" % fm(x), "#2a1e14", stroke="#1a120c", stroke_width=1.4)
	d.ellipse(152, 96, 18, 6, "#1a1a1e", opacity=0.8)
	d.line(150, 92, 120, 20, INK, 12)
	d.line(150, 92, 120, 20, BRASS, 7)
	d.circle(118, 18, 9, BRASS_D, stroke=INK, stroke_width=3)


def _ledger_doodle(kind):
	def f(d):
		if kind == "rose":
			d.circle(146, 152, 10, "#c0392b", stroke=INK, stroke_width=2.5)
			d.spath("M146 162 L146 182 M146 170 q8 -2 10 -10", "#2a6a3a", 3)
		elif kind == "paper":
			d.rect(132, 146, 34, 24, "#e8e2d0", stroke=INK, stroke_width=2.5)
			d.rect(136, 150, 26, 5, "#3a3a40")
		elif kind == "spoon":
			d.ellipse(150, 150, 10, 14, SILVER, stroke=INK, stroke_width=2.5)
			d.line(150, 162, 150, 186, SILVER_D, 4)
		elif kind == "belt":
			d.rect(128, 154, 44, 10, "#1a1a1e", stroke=INK, stroke_width=2)
			d.path("M148 154 L144 176 L152 172 L156 176 L154 154 Z", "#1a1a1e", stroke=INK, stroke_width=2)
		elif kind == "brush":
			d.line(132, 184, 162, 146, WOOD, 5)
			d.path("M158 150 L170 136 L172 146 Z", "#c0392b", stroke=INK, stroke_width=2)
		elif kind == "flask":
			d.path("M144 140 L152 140 L152 152 L164 178 L132 178 L144 152 Z", "#bfe8d8", stroke=INK, stroke_width=2.5)
			d.circle(150, 132, 5, "#ffffff", opacity=0.8)
	return f


def clue_ledger_terrace(d):
	ledger_page_icon(d, 351, lambda: _ledger_doodle("rose")(d))


def clue_ledger_hall(d):
	ledger_page_icon(d, 352, lambda: _ledger_doodle("paper")(d))


def clue_ledger_dining(d):
	ledger_page_icon(d, 353, lambda: _ledger_doodle("spoon")(d))


def clue_ledger_kitchen(d):
	ledger_page_icon(d, 354, lambda: _ledger_doodle("belt")(d))


def clue_ledger_music(d):
	ledger_page_icon(d, 355, lambda: _ledger_doodle("brush")(d))


def clue_ledger_library(d):
	ledger_page_icon(d, 356, lambda: _ledger_doodle("flask")(d))


def clue_ledger_wing(d):
	ledger_page_icon(d, 357, None, True)
	d.path("M60 160 L74 152 L86 164 L100 154 L112 166 L124 156 L136 168", "none", stroke="#d8cfbc", stroke_width=3, stroke_dasharray="4 4")


def clue_burned_glove(d):
	ishadow(d, 100, 186, 70, 8)
	d.path("M40 110 Q30 60 52 42 L62 42 L64 26 Q72 18 80 26 L82 40 L90 18 Q100 10 106 20 L104 44 L118 28 Q128 22 132 32 L118 72 Q140 80 150 100 L120 140 L60 150 Z",
		"#7cb342", stroke=INK, stroke_width=OL, stroke_linejoin="round")
	d.path("M60 150 L120 140 L132 170 Q100 186 60 176 Z", "#5a8a32", stroke=INK, stroke_width=3.5)
	# the burned half
	d.path("M96 60 L150 100 L120 140 L84 120 Q100 96 96 60 Z", "#2a221c", stroke=INK, stroke_width=3)
	d.path("M96 60 Q102 90 84 120", "none", stroke="#e8553d", stroke_width=3, opacity=0.8)
	d.path("M54 84 Q66 74 80 86", "none", stroke="#9a958c", stroke_width=4, opacity=0.9)
	for k in range(3):
		d.spath("M%s 30 q-6 -8 0 -16" % fm(150 + k * 10), "#8a8a8a", 2.6, opacity=0.6)


def clue_painted_page(d):
	ishadow(d, 100, 186, 72, 8)
	with G(d, transform="rotate(-6 100 100)"):
		d.rect(26, 40, 148, 112, PAPER, stroke=INK, stroke_width=OL)
		d.rect(32, 46, 136, 50, "#8ab0c8")
		d.rect(32, 96, 136, 50, "#5a7a92")
		d.path("M120 92 L124 64 L140 92 Z", "#ffffff", stroke=INK, stroke_width=2)
		d.rect(48, 88, 30, 8, "#6a6a72")
		for k in range(3):
			d.spath("M40 %s q20 -6 40 0 t40 0 t40 0" % fm(108 + k * 12), "#3a5a72", 2.4)
		# typing showing through, backwards
		for j in range(5):
			d.rect(132 - j * 9, 132, 6, 6, "#3a3a40", opacity=0.35)
	d.rect(150, 24, 10, 60, WOOD, stroke=INK, stroke_width=2, transform="rotate(30 155 54)")


def clue_dead_camera(d):
	ishadow(d, 100, 186, 66, 8)
	d.rect(20, 20, 160, 22, WOOD_D, stroke=INK, stroke_width=3.5)
	B.croc_cam(d, 100, 96, 1.6, lit=False)
	d.rect(116, 92, 34, 14, "#14141a", rx=3, transform="rotate(-12 133 99)")
	d.spath("M70 44 Q60 60 76 72 M82 44 Q96 58 84 70", "#c0392b", 3)
	d.spath("M68 72 l-4 8 M86 70 l6 6", SILVER, 2.4)


def clue_moustache_wax(d):
	ishadow(d, 100, 186, 66, 8)
	tin(d, 100, 104, 54, 40, "#d8b040", "#f0d070")
	d.ellipse(100, 106, 44, 14, "#f4e2b0")
	d.path("M84 100 Q100 116 116 100", "none", stroke="#c8a860", stroke_width=5)
	with G(d, transform="rotate(30 150 60)"):
		d.ellipse(150, 60, 40, 13, "#d8b040", stroke=INK, stroke_width=OL)
		d.path("M134 58 Q150 48 166 58 Q150 52 134 58 Z", INK)
	d.path("M52 170 Q70 150 100 162 Q130 150 148 170 Q120 168 100 176 Q80 168 52 170 Z", "#3a2a1e", stroke=INK, stroke_width=2.5)


def clue_music_box(d):
	ishadow(d, 100, 186, 76, 9)
	d.path("M20 110 L180 110 L172 176 L28 176 Z", "#8a3a4a", stroke=INK, stroke_width=OL, stroke_linejoin="round")
	for x in (54, 100, 146):
		d.circle(x, 142, 9, "#e8a0b0", stroke=INK, stroke_width=2)
	d.path("M20 110 L36 54 L164 54 L180 110 Z", "#a04a5a", stroke=INK, stroke_width=OL)
	d.rect(90, 30, 20, 30, "#f4c0d0", stroke=INK, stroke_width=2.5, rx=8)
	d.circle(100, 26, 7, "#f4c0d0", stroke=INK, stroke_width=2.5)
	with G(d, transform="rotate(-12 150 80)"):
		d.rect(126, 64, 50, 36, PAPER, stroke=INK, stroke_width=2.5)
		d.ellipse(150, 86, 12, 8, "#c8885a", stroke=INK, stroke_width=1.6)
		d.path("M134 80 Q150 64 166 80 Z", LILAC, stroke=INK, stroke_width=1.6)
	d.rect(176, 126, 18, 8, BRASS, stroke=INK, stroke_width=2)


# --------------------------------------------------------------------------------------

def main():
	args = sys.argv[1:]
	only = None
	if "--only" in args:
		only = set(args[args.index("--only") + 1].split(","))
	pr_dir = os.path.join(ROOT, "art", "props")
	os.makedirs(pr_dir, exist_ok=True)
	bad = ("<text", "<filter", "<image", "<style", "href")
	for cid in IDS:
		if only and cid not in only:
			continue
		d = Doc(200, 200)
		globals()["clue_" + cid](d)
		txt = d.svg()
		for b in bad:
			if b in txt:
				raise SystemExit("forbidden SVG content %r in clue_%s" % (b, cid))
		with open(os.path.join(pr_dir, "clue_" + cid + ".svg"), "w", encoding="utf-8") as f:
			f.write(txt)
		print("icon %-20s %5.1f KB" % (cid, len(txt) / 1024.0))


if __name__ == "__main__":
	main()
