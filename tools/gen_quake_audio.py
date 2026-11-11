#!/usr/bin/env python3
"""SPLASH TRIAL - Case 3 earthquake, flood and tunnel cutscene SFX (flow step `quake`).

Writes audio/sfx/qk_*.wav (16-bit PCM, 44.1 kHz, mono) for scripts/screens/quake_screen.gd and the story:
  qk_tremor    a small, sleepy tremor: low grumble + a faint rattle (also the last line of Case 2's epilogue)
  qk_rattle    a china cup chattering on its saucer               qk_pebbles  grit and pebbles trickling down rock
  qk_watch     a pocket watch: four ticks and a tiny chime        qk_click    the detonator plunger slammed home
  qk_beep      one charge's arming beep                           qk_quake    the big one: rock roar, grinding, cracking
  qk_crack     rock splitting along a wall                        qk_crash    a stalactite smashing on the mud
  qk_burst     a cave wall blown open by a lake                   qk_flood    a roaring wall of water
  qk_snap      a mooring rope parting (twang + whip)              qk_rush     racing down a tunnel: wind, water, rock
  qk_whoosh    a rock rib flashing past                           qk_scrape   steel smokestack sheared on rock
  qk_rise      a rising rush into the light                       qk_splash   a paddle-steamer landing in the sea
  qk_waves     calm waves lapping                                 qk_gulls    a few gulls, far off
  qk_shutter   a camera shutter

Pure standard library, fully synthesized and deterministic (fixed seeds). The DSP helpers come from
tools/gen_drain_audio.py (imported read-only); loudness conventions match it.

    python3 tools/gen_quake_audio.py              # render everything
    python3 tools/gen_quake_audio.py qk_snap      # render only these ids
"""
import math
import os
import random
import sys
import zlib

sys.dont_write_bytecode = True
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gen_drain_audio as DA  # noqa: E402  (helpers only - never modified)
from gen_drain_audio import (SR, TAU, n_of, zeros, noise, lp1, hp1, biquad, osc, env, mul, add_into, scale,  # noqa: E402
	tanh_sat, adsr_exp, reverb, finish, bubble, metal_hit)


def R(name):
	return random.Random(zlib.crc32(("qk/" + name).encode()))


def write(name, x):
	DA.write(name, x)


def thump(dur, f0, f1, decay, n=None):
	"""A pitched-down sine hit (f0 falling to f1)."""
	n = n or n_of(dur)
	out = [0.0] * n
	ph = 0.0
	for i in range(n):
		t = i / SR
		f = f1 + (f0 - f1) * math.exp(-t / 0.05)
		ph += f / SR
		out[i] = math.sin(TAU * ph) * math.exp(-t / decay) * min(1.0, t / 0.002)
	return out


def rumble_bed(rng, dur, fc=90.0, sub=34.0):
	n = n_of(dur)
	br = lp1(lp1(noise(n, rng), fc), fc * 0.8)
	s = osc(lambda t: sub + 5.0 * math.sin(TAU * 0.6 * t) + 2.5 * math.sin(TAU * 1.7 * t), n)
	return [9.0 * a + 0.5 * b for a, b in zip(br, s)]


def clinks(rng, y, t0, t1, rate, gain, base=1.0):
	"""Little china clinks scattered between t0 and t1."""
	t = t0
	while t < t1:
		m = n_of(0.08)
		f = rng.uniform(2600, 4200) * base
		c = [(math.sin(TAU * f * tt) + 0.5 * math.sin(TAU * f * 2.7 * tt)) * math.exp(-tt / 0.018) for tt in (i / SR for i in range(m))]
		add_into(y, c, t, gain * rng.uniform(0.4, 1.0))
		t += rng.uniform(0.3, 1.0) / rate


def rock_hits(rng, y, t0, t1, rate, gain, dark=1.0):
	"""Knocks of stone on stone."""
	t = t0
	while t < t1:
		m = n_of(0.12)
		k = biquad(noise(m, rng), "bp", rng.uniform(300, 900) / dark, 2.5)
		k = [v * math.exp(-(i / SR) / 0.025) * 4.0 for i, v in enumerate(k)]
		add_into(y, k, t, gain * rng.uniform(0.3, 1.0))
		t += rng.uniform(0.2, 1.0) / rate


# ------------------------------------------------------------------ the sounds
def qk_tremor():
	rng = R("tremor")
	dur = 3.2
	n = n_of(dur)
	bed = rumble_bed(rng, dur, 70.0, 30.0)
	shape = env(n, lambda t: math.sin(math.pi * min(1.0, t / dur)) ** 1.5)
	y = mul(bed, shape)
	clinks(rng, y, 0.6, 2.4, 6.0, 0.12)
	return finish(reverb(tanh_sat(y, 1.2), 2.0, 0.35, 0.3, 1.0), rms_db=-22.0)


def qk_rattle():
	rng = R("rattle")
	dur = 1.4
	y = zeros(n_of(dur))
	t = 0.0
	while t < 1.15:
		m = n_of(0.05)
		f = rng.uniform(2200, 3600)
		c = [(math.sin(TAU * f * tt) + 0.6 * math.sin(TAU * f * 2.4 * tt + 0.4) + 0.3 * math.sin(TAU * f * 3.9 * tt)) * math.exp(-tt / 0.012)
			for tt in (i / SR for i in range(m))]
		g = (0.5 + 0.5 * math.sin(math.pi * t / 1.15)) * rng.uniform(0.5, 1.0)
		add_into(y, c, t, g)
		t += rng.uniform(0.018, 0.05)
	# the saucer's lower rattle underneath
	sw = biquad(noise(n_of(dur), rng), "bp", 900, 6)
	sw = [v * 0.6 * (0.5 + 0.5 * math.sin(TAU * 18 * i / SR)) * math.sin(math.pi * min(1.0, i / SR / 1.2)) for i, v in enumerate(sw)]
	y = [a + b for a, b in zip(y, sw)]
	return finish(reverb(y, 0.9, 0.2, 0.7, 0.4), rms_db=-23.0)


def qk_pebbles():
	rng = R("pebbles")
	dur = 1.8
	y = zeros(n_of(dur))
	rock_hits(rng, y, 0.0, 1.4, 14.0, 0.5)
	t = 0.0
	while t < 1.4:
		m = n_of(0.03)
		g = hp1(noise(m, rng), 3000.0)
		add_into(y, [v * math.exp(-(i / SR) / 0.006) for i, v in enumerate(g)], t, 0.4 * rng.uniform(0.3, 1.0))
		t += rng.uniform(0.008, 0.04)
	return finish(reverb(y, 1.8, 0.4, 0.5, 0.8), rms_db=-24.0)


def qk_watch():
	rng = R("watch")
	dur = 2.6
	y = zeros(n_of(dur))
	for k in range(4):
		m = n_of(0.05)
		f = 3400 if k % 2 == 0 else 2900
		tk = [(math.sin(TAU * f * tt) + 0.5 * math.sin(TAU * f * 1.9 * tt)) * math.exp(-tt / 0.007) for tt in (i / SR for i in range(m))]
		cl = hp1(noise(m, rng), 2000.0)
		add_into(y, [a + b * 0.5 * math.exp(-(i / SR) / 0.004) for i, (a, b) in enumerate(zip(tk, cl))], k * 0.5, 0.8)
	m = n_of(1.0)
	ch = [(math.sin(TAU * 1975 * tt) + 0.5 * math.sin(TAU * 2960 * tt) + 0.2 * math.sin(TAU * 5270 * tt)) * math.exp(-tt / 0.3) * min(1.0, tt / 0.002)
		for tt in (i / SR for i in range(m))]
	add_into(y, ch, 1.95, 0.35)
	return finish(reverb(y, 1.0, 0.25, 0.8, 0.5), rms_db=-24.0)


def qk_click():
	rng = R("click")
	dur = 0.9
	n = n_of(dur)
	y = zeros(n)
	# spring compress (a short rising squeak) then the clunk home
	m = n_of(0.12)
	sq = osc(lambda t: 900 + 2600 * t / 0.12, m, "tri")
	add_into(y, [v * 0.15 * math.sin(math.pi * i / m) for i, v in enumerate(sq)], 0.0)
	add_into(y, thump(0.6, 160, 70, 0.08), 0.12, 1.2)
	add_into(y, metal_hit(rng, 0.4, 0.9), 0.12, 0.6)
	k = biquad(noise(n_of(0.2), rng), "bp", 420, 2)
	add_into(y, [v * math.exp(-(i / SR) / 0.03) * 4.0 for i, v in enumerate(k)], 0.12, 1.0)
	return finish(reverb(tanh_sat(y, 1.4), 1.0, 0.3, 0.6, 0.5), rms_db=-17.0)


def qk_beep():
	dur = 0.18
	n = n_of(dur)
	y = [(math.sin(TAU * 1480 * t) * 0.7 + (1.0 if math.sin(TAU * 740 * t) > 0 else -1.0) * 0.25) * min(1.0, t / 0.004) * min(1.0, (dur - t) / 0.02)
		for t in (i / SR for i in range(n))]
	y = biquad(y, "lp", 5000, 0.7)
	return finish(reverb(y, 1.2, 0.3, 0.7, 0.4), rms_db=-21.0)


def qk_quake():
	rng = R("quake")
	dur = 8.5
	n = n_of(dur)
	bed = rumble_bed(rng, dur, 110.0, 32.0)
	grind = biquad(noise(n, rng), "bp", 220, 1.2, fc_fn=lambda t: 160 + 120 * math.sin(TAU * 0.4 * t) + 60 * math.sin(TAU * 2.3 * t))
	roar = lp1(lp1(noise(n, rng), 600.0), 900.0)
	shape = env(n, lambda t: min(1.0, t / 0.25) * (1.0 - max(0.0, (t - 6.8) / 1.7)) * (0.75 + 0.25 * math.sin(TAU * 1.3 * t) * math.sin(TAU * 0.37 * t)))
	y = [(a + 1.2 * b + 2.2 * c) * s for a, b, c, s in zip(bed, grind, roar, shape)]
	rock_hits(rng, y, 0.3, 7.0, 6.0, 0.9, dark=1.5)
	t = 0.4
	while t < 6.6:
		cr = biquad(noise(n_of(0.25), rng), "bp", rng.uniform(900, 2200), 1.5)
		cr = [v * math.exp(-(i / SR) / 0.04) * 3.0 for i, v in enumerate(cr)]
		add_into(y, cr, t, rng.uniform(0.2, 0.6))
		t += rng.uniform(0.4, 1.1)
	return finish(reverb(tanh_sat(y, 1.6), 2.6, 0.4, 0.3, 1.5), rms_db=-15.0)


def qk_crack():
	rng = R("crack")
	dur = 1.0
	y = zeros(n_of(dur))
	t = 0.0
	g = 1.0
	while t < 0.55:
		m = n_of(0.06)
		c = biquad(noise(m, rng), "bp", rng.uniform(1500, 3500), 1.2)
		add_into(y, [v * math.exp(-(i / SR) / 0.01) * 3.0 for i, v in enumerate(c)], t, g)
		t += rng.uniform(0.01, 0.05)
		g *= 0.94
	add_into(y, thump(0.5, 120, 50, 0.12), 0.0, 0.8)
	return finish(reverb(tanh_sat(y, 1.3), 1.8, 0.4, 0.6, 0.8), rms_db=-18.0)


def qk_crash():
	rng = R("crash")
	dur = 1.4
	y = zeros(n_of(dur))
	add_into(y, thump(1.0, 110, 38, 0.25), 0.0, 1.3)
	sh = biquad(noise(n_of(0.6), rng), "lp", 3000, 0.7, fc_fn=lambda t: 4000 * math.exp(-t / 0.15) + 500)
	add_into(y, [v * adsr_exp(i / SR, 0.002, 0.12) * 1.5 for i, v in enumerate(sh)], 0.0, 1.0)
	rock_hits(rng, y, 0.05, 0.8, 18.0, 0.7)
	sq = biquad(noise(n_of(0.5), rng), "bp", 400, 2, fc_fn=lambda t: 300 + 600 * t)
	add_into(y, [v * adsr_exp(i / SR, 0.03, 0.15) for i, v in enumerate(sq)], 0.02, 0.6)
	return finish(reverb(tanh_sat(y, 1.5), 2.0, 0.4, 0.5, 1.0), rms_db=-16.0)


def qk_burst():
	rng = R("burst")
	dur = 3.4
	n = n_of(dur)
	y = zeros(n)
	add_into(y, thump(2.0, 90, 28, 0.6), 0.0, 1.6)
	blast = biquad(noise(n, rng), "lp", 3000, 0.7, fc_fn=lambda t: 6000 * math.exp(-t / 0.5) + 400)
	y = [a + b * adsr_exp(i / SR, 0.003, 0.7) * 1.4 for i, (a, b) in enumerate(zip(y, blast))]
	water = lp1(lp1(noise(n, rng), 1600.0), 2200.0)
	y = [a + b * min(1.0, (i / SR) / 0.3) * math.exp(-max(0.0, i / SR - 1.0) / 1.2) * 1.6 for i, (a, b) in enumerate(zip(y, water))]
	rock_hits(rng, y, 0.02, 1.6, 12.0, 0.9, dark=1.3)
	t = 0.3
	while t < 2.6:
		add_into(y, bubble(rng.uniform(200, 700), rng.uniform(0.04, 0.1), 2.0), t, rng.uniform(0.1, 0.3))
		t += rng.uniform(0.03, 0.12)
	return finish(reverb(tanh_sat(y, 1.6), 2.6, 0.45, 0.4, 1.5), rms_db=-14.0)


def qk_flood():
	rng = R("flood")
	dur = 6.5
	n = n_of(dur)
	body = lp1(lp1(noise(n, rng), 1400.0), 2000.0)
	hiss = hp1(lp1(noise(n, rng), 7000.0), 2400.0)
	low = lp1(lp1(noise(n, rng), 110.0), 90.0)
	surge = biquad(noise(n, rng), "bp", 500, 1.0, fc_fn=lambda t: 400 + 250 * math.sin(TAU * 0.8 * t))
	shape = env(n, lambda t: min(1.0, (t / 0.6) ** 1.2) * (1.0 - max(0.0, (t - 5.0) / 1.5)) * (0.85 + 0.15 * math.sin(TAU * 0.7 * t)))
	y = [(a + 0.3 * b + 7.0 * c + 0.8 * d) * s for a, b, c, d, s in zip(body, hiss, low, surge, shape)]
	return finish(reverb(tanh_sat(y, 1.3), 2.4, 0.4, 0.4, 1.2), rms_db=-16.0)


def qk_snap():
	rng = R("snap")
	dur = 1.2
	n = n_of(dur)
	y = zeros(n)
	# the strained creak just before
	m = n_of(0.16)
	cr = biquad(noise(m, rng), "bp", 600, 8, fc_fn=lambda t: 500 + 1500 * t / 0.16)
	add_into(y, [v * 2.0 * (i / m) for i, v in enumerate(cr)], 0.0, 1.0)
	# the crack of the fibres parting
	c = hp1(noise(n_of(0.05), rng), 1500.0)
	add_into(y, [v * math.exp(-(i / SR) / 0.008) * 3.0 for i, v in enumerate(c)], 0.16, 1.2)
	# the twang + whip of the loose end
	tw = osc(lambda t: 110 * (1 + 0.5 * math.exp(-t / 0.05)), n_of(0.7), "saw")
	tw = biquad(tw, "lp", 1200, 3)
	add_into(y, [v * math.exp(-(i / SR) / 0.16) for i, v in enumerate(tw)], 0.16, 0.8)
	wh = biquad(noise(n_of(0.35), rng), "bp", 1500, 1.5, fc_fn=lambda t: 3500 - 6000 * t)
	add_into(y, [v * math.sin(math.pi * min(1.0, i / n_of(0.35))) * 2.0 for i, v in enumerate(wh)], 0.2, 0.9)
	return finish(reverb(tanh_sat(y, 1.4), 1.6, 0.35, 0.6, 0.8), rms_db=-17.0)


def qk_rush():
	rng = R("rush")
	dur = 7.0
	n = n_of(dur)
	wind = biquad(noise(n, rng), "bp", 800, 0.8, fc_fn=lambda t: 700 + 300 * math.sin(TAU * 0.5 * t))
	water = lp1(lp1(noise(n, rng), 1800.0), 2400.0)
	low = rumble_bed(rng, dur, 100.0, 38.0)
	shape = env(n, lambda t: min(1.0, t / 0.4) * (1.0 - max(0.0, (t - 5.8) / 1.2)))
	y = [(0.8 * a + 1.0 * b + 0.5 * c) * s for a, b, c, s in zip(wind, water, low, shape)]
	# ribs whooshing past at an even beat
	t = 0.3
	while t < 6.2:
		m = n_of(0.3)
		wh = biquad(noise(m, rng), "bp", 1200, 1.2, fc_fn=lambda tt: 2200 - 4000 * tt)
		add_into(y, [v * math.sin(math.pi * i / m) ** 2 * 2.0 for i, v in enumerate(wh)], t, 0.6)
		t += 0.29
	return finish(reverb(tanh_sat(y, 1.2), 2.2, 0.4, 0.5, 1.0), rms_db=-17.0)


def qk_whoosh():
	rng = R("whoosh")
	dur = 0.5
	n = n_of(dur)
	wh = biquad(noise(n, rng), "bp", 900, 1.3, fc_fn=lambda t: 2600 - 4400 * t)
	low = lp1(noise(n, rng), 200.0)
	y = [(a * 1.5 + b * 4.0) * math.sin(math.pi * min(1.0, (i / SR) / dur)) ** 2 for i, (a, b) in enumerate(zip(wh, low))]
	return finish(reverb(y, 1.2, 0.3, 0.6, 0.4), rms_db=-19.0)


def qk_scrape():
	rng = R("scrape")
	dur = 2.0
	n = n_of(dur)
	y = zeros(n)
	# the clang
	add_into(y, metal_hit(rng, 1.2, 0.55), 0.0, 1.4)
	add_into(y, metal_hit(rng, 0.9, 0.8), 0.01, 0.9)
	add_into(y, thump(0.8, 140, 55, 0.2), 0.0, 1.0)
	# the shriek of steel on rock
	m = n_of(1.3)
	sc = osc(lambda t: 1300 + 500 * math.sin(TAU * 7 * t) - 400 * t, m, "saw")
	sc = biquad(sc, "bp", 1800, 3)
	gr = biquad(noise(m, rng), "bp", 2500, 1.5)
	add_into(y, [(a * 0.7 + b) * math.exp(-(i / SR) / 0.5) * min(1.0, (i / SR) / 0.02) for i, (a, b) in enumerate(zip(sc, gr))], 0.05, 0.9)
	rock_hits(rng, y, 0.1, 1.2, 10.0, 0.5)
	return finish(reverb(tanh_sat(y, 1.5), 2.0, 0.4, 0.6, 1.0), rms_db=-15.0)


def qk_rise():
	rng = R("rise")
	dur = 1.6
	n = n_of(dur)
	sw = biquad(noise(n, rng), "bp", 500, 1.5, fc_fn=lambda t: 300 + 5000 * (t / dur) ** 2)
	tone = osc(lambda t: 220 * 2 ** (2.0 * t / dur), n, "tri")
	shape = env(n, lambda t: (t / dur) ** 1.6)
	y = [(a * 2.0 + b * 0.25) * s for a, b, s in zip(sw, tone, shape)]
	return finish(reverb(y, 1.6, 0.35, 0.7, 0.6), rms_db=-17.0)


def qk_splash():
	rng = R("splash")
	dur = 4.2
	n = n_of(dur)
	y = zeros(n)
	add_into(y, thump(2.2, 80, 26, 0.7), 0.0, 1.8)
	crash = biquad(noise(n, rng), "lp", 3000, 0.7, fc_fn=lambda t: 7000 * math.exp(-t / 0.35) + 600)
	y = [a + b * adsr_exp(i / SR, 0.003, 0.5) * 1.5 for i, (a, b) in enumerate(zip(y, crash))]
	# the spray coming back down: a long patter
	pat = hp1(noise(n, rng), 1800.0)
	y = [a + b * 0.5 * (math.sin(math.pi * min(1.0, max(0.0, (i / SR - 0.4) / 3.4)))) for i, (a, b) in enumerate(zip(y, pat))]
	t = 0.4
	while t < 3.5:
		add_into(y, bubble(rng.uniform(250, 1200), rng.uniform(0.03, 0.09), 2.4), t, rng.uniform(0.05, 0.25))
		t += rng.uniform(0.02, 0.1)
	return finish(reverb(tanh_sat(y, 1.5), 2.2, 0.35, 0.5, 1.2), rms_db=-14.0)


def qk_waves():
	rng = R("waves")
	dur = 7.0
	n = n_of(dur)
	y = zeros(n)
	for (t0, ln, g) in [(0.0, 2.6, 0.8), (2.2, 2.8, 1.0), (4.6, 2.4, 0.7)]:
		m = n_of(ln)
		w = biquad(noise(m, rng), "bp", 700, 0.7, fc_fn=lambda t, ln=ln: 500 + 900 * math.sin(math.pi * t / ln))
		w = [v * math.sin(math.pi * (i / m)) ** 2 for i, v in enumerate(w)]
		add_into(y, w, t0, g)
	low = lp1(noise(n, rng), 150.0)
	y = [a + b * 3.0 for a, b in zip(y, low)]
	shape = env(n, lambda t: min(1.0, t / 0.6) * min(1.0, (dur - t) / 0.8))
	return finish(reverb(mul(y, shape), 1.2, 0.25, 0.6, 0.6), rms_db=-24.0)


def gull(rng, dur, f0):
	n = n_of(dur)
	out = [0.0] * n
	ph = 0.0
	for i in range(n):
		t = i / SR
		k = t / dur
		f = f0 * (1.0 + 0.35 * math.sin(math.pi * k)) * (1 - 0.25 * k)
		ph += f / SR
		v = math.sin(TAU * ph) + 0.6 * math.sin(TAU * 2 * ph + 0.3) + 0.35 * math.sin(TAU * 3 * ph)
		out[i] = v * math.sin(math.pi * k) ** 0.8
	return biquad(out, "bp", f0 * 2.2, 1.0)


def qk_gulls():
	rng = R("gulls")
	dur = 5.0
	y = zeros(n_of(dur))
	for (t, d_, f) in [(0.2, 0.32, 900), (0.6, 0.26, 980), (0.95, 0.22, 1040), (2.4, 0.36, 860), (2.85, 0.3, 940), (4.0, 0.28, 1020)]:
		add_into(y, gull(rng, d_, f), t, rng.uniform(0.6, 1.0))
	return finish(reverb(y, 2.0, 0.35, 0.7, 1.2), rms_db=-24.0)


def qk_shutter():
	rng = R("shutter")
	dur = 0.35
	y = zeros(n_of(dur))
	for (t, g, f) in [(0.0, 1.0, 2400), (0.07, 0.7, 1800)]:
		m = n_of(0.06)
		c = biquad(noise(m, rng), "bp", f, 3)
		add_into(y, [v * math.exp(-(i / SR) / 0.006) * 4.0 for i, v in enumerate(c)], t, g)
	m = n_of(0.2)
	wn = biquad(noise(m, rng), "bp", 1200, 4, fc_fn=lambda t: 900 + 1600 * t / 0.2)
	add_into(y, [v * 0.4 * math.sin(math.pi * i / m) for i, v in enumerate(wn)], 0.1, 1.0)
	return finish(reverb(y, 0.6, 0.15, 0.8, 0.2), rms_db=-21.0)


SOUNDS = ["qk_tremor", "qk_rattle", "qk_pebbles", "qk_watch", "qk_click", "qk_beep", "qk_quake", "qk_crack", "qk_crash", "qk_burst",
	"qk_flood", "qk_snap", "qk_rush", "qk_whoosh", "qk_scrape", "qk_rise", "qk_splash", "qk_waves", "qk_gulls", "qk_shutter"]


def main():
	only = set(sys.argv[1:])
	g = globals()
	for name in SOUNDS:
		if only and name not in only:
			continue
		write(name, g[name]())


if __name__ == "__main__":
	main()
