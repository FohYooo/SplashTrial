#!/usr/bin/env python3
"""
SPLASH TRIAL - horror execution audio ("THE FINAL VANISHING ACT").

Renders the cursed-broadcast execution soundtrack and its SFX as 16-bit PCM, 32 kHz, mono WAV
(same format, loudness targets and DSP helpers as tools/gen_audio.py, which is imported read-only):

    audio/music/execution_horror.wav   ~60 s seamless loop: detuned music box on a warbling tape,
                                       a crawling far-away calliope, low beating drones, heartbeats, wind
    audio/sfx/hx_*.wav                 heartbeat, thud, creak, slam, chain, blade, drone_hit, swell, laugh,
                                       whisper, static_burst, standby, buzz, servo, applause_stiff, turn,
                                       sting, musicbox, thunder, drip, splatter, wind, end_tone

Everything is synthesized (no samples, no real voices) and deterministic.

    python3 tools/gen_horror_audio.py            # render everything + print the analysis table
    python3 tools/gen_horror_audio.py hx_laugh   # render only these ids
"""
import math
import os
import sys
import zlib

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gen_audio as GA  # noqa: E402  (helpers only - never modified)

SR = GA.SR
TAU = GA.TAU
nlen, _t, place, lp1, hp1, bq, bq_sweep = GA.nlen, GA._t, GA.place, GA.lp1, GA.hp1, GA.bq, GA.bq_sweep
room, finish_sfx, undb, db, rms = GA.room, GA.finish_sfx, GA.undb, GA.db, GA.rms
MUSIC_DIR, SFX_DIR = GA.MUSIC_DIR, GA.SFX_DIR


def R(name):
	return np.random.default_rng(zlib.crc32(("hx/" + name).encode()))


def nz(n, rng):
	return rng.standard_normal(n)


def sweep_sin(f, n):
	"""Sine with a per-sample frequency array (or scalar)."""
	f = np.broadcast_to(np.asarray(f, float), (n,))
	return np.sin(TAU * np.cumsum(f) / SR)


def bump(t, t0, a, d):
	"""Attack/decay envelope starting at t0."""
	u = t - t0
	return np.where(u < 0, 0.0, np.minimum(1.0, u / max(a, 1e-5)) * np.exp(-np.maximum(0.0, u - a) / d))


def stick_slip(n, rng, rate_lo, rate_hi, wobble=1.3):
	"""Impulse train of a creaking hinge / joint: irregular rate, random impulse heights."""
	t = _t(n)
	slow = lp1(lp1(nz(n, rng), 3.0), 3.0)
	slow = slow / (np.max(np.abs(slow)) + 1e-9)
	rate = rate_lo + (rate_hi - rate_lo) * (0.5 + 0.5 * np.sin(TAU * wobble * t + rng.random() * TAU)) * (0.7 + 0.3 * slow)
	ph = np.cumsum(rate) / SR
	idx = np.nonzero(np.diff(np.floor(ph)) > 0)[0]
	x = np.zeros(n)
	x[idx] = rng.uniform(0.4, 1.0, len(idx)) * np.where(rng.random(len(idx)) < 0.15, 1.8, 1.0)
	return x


def wood_body(x):
	return (bq(x, "bp", 420, 6) + 0.75 * bq(x, "bp", 980, 8) + 0.45 * bq(x, "bp", 1750, 10)
		+ 0.25 * bq(x, "bp", 2900, 12) + 0.3 * bq(x, "bp", 230, 4))


def formant_voice(src, vowel, shift=1.0):
	F = {"a": ((750, 1.0, 9), (1200, 0.7, 10), (2550, 0.35, 12)),
		"o": ((480, 1.0, 9), (860, 0.6, 10), (2400, 0.2, 12)),
		"e": ((420, 1.0, 9), (2000, 0.55, 12), (2700, 0.3, 12)),
		"u": ((330, 1.0, 9), (760, 0.4, 10), (2300, 0.15, 12))}[vowel]
	y = np.zeros(len(src))
	for fc, g, q in F:
		y += g * bq(src, "bp", fc * shift, q)
	return y


def crush(x, hold=3, bits=6):
	"""Sample-and-hold + quantize: cheap 'broadcast damage'."""
	idx = (np.arange(len(x)) // hold) * hold
	y = x[np.minimum(idx, len(x) - 1)]
	q = 2.0 ** (bits - 1)
	return np.round(y * q) / q


# =====================================================================================  SFX
def hx_heartbeat():
	rng = R("heartbeat")
	out = np.zeros(nlen(1.15))
	for t0, a, f0 in ((0.0, 1.0, 46.0), (0.27, 0.72, 53.0)):
		n = nlen(0.5)
		t = _t(n)
		y = sweep_sin(f0 + 34 * np.exp(-t / 0.025), n) * np.minimum(1, t / 0.006) * np.exp(-t / 0.13)
		y += 0.3 * lp1(nz(n, rng), 110) * np.exp(-t / 0.05)
		place(out, y, t0, a)
	y = np.tanh(2.2 * lp1(out, 210))
	return finish_sfx(room(y, 0.7, 0.1, bright=0.3), loud=-13)


def hx_thud():
	rng = R("thud")
	n = nlen(2.8)
	t = _t(n)
	sub = sweep_sin(36 + 80 * np.exp(-t / 0.045), n) * np.exp(-t / 0.38) * np.minimum(1, t / 0.0015)
	knock = GA._wood(n, rng, [(150, 1.0, 0.09), (265, 0.7, 0.06), (470, 0.45, 0.035), (720, 0.25, 0.02)], imp=1.1)
	metal = np.zeros(n)
	for fm, a, d in ((1180, 0.5, 0.35), (2230, 0.35, 0.22), (3470, 0.25, 0.15), (4690, 0.15, 0.1)):
		metal += a * np.sin(TAU * fm * t) * np.exp(-t / d)
	metal += 0.8 * hp1(nz(n, rng), 3000) * np.exp(-t / 0.004)
	y = np.tanh(1.6 * (1.1 * sub + 0.8 * knock + 0.16 * metal))
	y = room(y, 2.4, 0.38, seed=11, bright=0.5)
	return finish_sfx(y, loud=-11)


def hx_slam():
	rng = R("slam")
	n = nlen(1.6)
	t = _t(n)
	hit = GA._wood(n, rng, [(110, 1.0, 0.12), (190, 0.8, 0.08), (340, 0.6, 0.05), (610, 0.35, 0.03)], imp=1.3)
	sub = sweep_sin(45 + 60 * np.exp(-t / 0.03), n) * np.exp(-t / 0.2)
	rattle = np.zeros(n)
	for k in range(9):
		t0 = 0.05 + k * 0.035 + rng.uniform(0, 0.02)
		m = nlen(0.05)
		tt = _t(m)
		r = bq(nz(m, rng), "bp", rng.uniform(1800, 3200), 6) * np.exp(-tt / 0.008)
		place(rattle, r, t0, 0.5 * (1 - k / 10))
	y = np.tanh(1.5 * (hit + 0.9 * sub + 0.5 * rattle))
	return finish_sfx(room(y, 1.6, 0.3, seed=5, bright=0.6), loud=-11)


def hx_creak():
	rng = R("creak")
	dur = 2.5
	n = nlen(dur)
	t = _t(n)
	x = stick_slip(n, rng, 28, 110, wobble=0.9)
	body = wood_body(x)
	env = np.sin(np.pi * np.clip(t / dur, 0, 1)) ** 0.5 * (0.65 + 0.35 * np.sin(TAU * 1.1 * t + 0.6))
	env *= np.minimum(1, t / 0.08)
	y = body * env
	y = room(y, 1.3, 0.28, seed=9, bright=0.7)
	return finish_sfx(y, loud=-15)


def hx_chain():
	rng = R("chain")
	out = np.zeros(nlen(1.9))
	GA.pings(out, rng, 70, 0.0, 0.85, 1900, 6400, 0.55, dmin=0.01, dmax=0.05, early=1.4)
	n = nlen(0.3)
	tt = _t(n)
	place(out, lp1(nz(n, rng), 300) * np.exp(-tt / 0.05) * 0.6, 0.02)
	# padlock snap
	m = nlen(0.6)
	tm = _t(m)
	click = hp1(nz(m, rng), 2500) * np.exp(-tm / 0.0018) * 1.6
	click += 0.5 * np.sin(TAU * 3150 * tm) * np.exp(-tm / 0.09) + 0.3 * np.sin(TAU * 4870 * tm) * np.exp(-tm / 0.05)
	click += 0.6 * sweep_sin(160 + 200 * np.exp(-tm / 0.01), m) * np.exp(-tm / 0.04)
	place(out, click, 1.0, 0.9)
	return finish_sfx(room(out, 1.2, 0.22, seed=4), loud=-15)


def hx_blade():
	rng = R("blade")
	dur = 0.55
	n = nlen(dur + 0.6)
	t = _t(n)
	g = np.clip(t / dur, 0, 1)
	env = np.where(t < dur, (g ** 1.6) * (1 - np.exp(-(dur - t) / 0.01)), 0.0)
	scrape = bq_sweep(nz(n, rng), "bp", 2800 + 4200 * g, 3.0, chunk=128) * (0.7 + 0.3 * np.sin(TAU * 47 * t))
	ring = np.zeros(n)
	for fm, a in ((2650, 1.0), (4120, 0.7), (5890, 0.45), (7310, 0.3)):
		ring += a * np.sin(TAU * fm * (1 + 0.01 * g) * t)
	ring_env = env * 0.5 + np.where(t >= dur, np.exp(-(t - dur) / 0.25), 0.0) * 0.8
	y = scrape * env + 0.18 * ring * ring_env
	return finish_sfx(room(y, 1.0, 0.2, seed=6), loud=-15)


def hx_drone_hit():
	rng = R("drone_hit")
	dur = 3.4
	n = nlen(dur)
	t = _t(n)
	boom = sweep_sin(28 + 100 * np.exp(-t / 0.07), n) * np.exp(-t / 0.8) * np.minimum(1, t / 0.002)
	cl = np.zeros(n)
	for m in (36, 37, 42, 43, 48, 49, 54):
		cl += GA.osc_saw(GA.midi_hz(m) * (1 + rng.uniform(-0.004, 0.004)), n, rng.random())
	cl = bq_sweep(cl, "lp", 300 + 5200 * np.exp(-t / 0.35), 1.2, chunk=128) * np.exp(-t / 1.3)
	scr = np.zeros(n)
	for fm in (1760, 1864, 2489, 2637, 3322):
		scr += np.sin(TAU * fm * t + rng.random() * TAU)
	scr *= (0.6 + 0.4 * np.sin(TAU * 13 * t)) * np.minimum(1, t / 0.01) * np.exp(-t / 0.9)
	burst = hp1(nz(n, rng), 800) * np.exp(-t / 0.05)
	y = np.tanh(1.8 * (1.2 * boom + 0.5 * cl / 4 + 0.12 * scr + 0.45 * burst))
	return finish_sfx(room(y, 2.8, 0.35, seed=13, bright=0.7), loud=-10)


def hx_swell():
	"""2.0 s rising dread swell that peaks exactly at its end (schedule it 2.0 s before a hit)."""
	rng = R("swell")
	dur = 2.0
	n = nlen(dur)
	t = _t(n)
	g = t / dur
	rev = bq_sweep(hp1(nz(n, rng), 900), "lp", 900 + 8000 * g ** 2, 0.8, chunk=128)
	low = np.zeros(n)
	for m in (31, 32, 38):
		low += GA.osc_saw(GA.midi_hz(m), n, rng.random())
	low = bq_sweep(low, "lp", 120 + 900 * g ** 2, 1.4, chunk=128)
	whine = np.sin(TAU * np.cumsum(900 + 1300 * g ** 1.5) / SR)
	y = (0.6 * rev + 0.5 * low / 3 + 0.12 * whine) * g ** 2.4
	y = GA.fade_out(y, 5)
	return finish_sfx(y, loud=-13)


def _syll(f0a, f0b, dur, rng, vowel="a", h=0.05, shift=0.72):
	n = nlen(dur + 0.05)
	t = _t(n)
	f0 = f0a + (f0b - f0a) * np.clip(t / dur, 0, 1)
	f0 = f0 * (1 + 0.012 * np.sin(TAU * 7 * t))
	ph = np.cumsum(f0) / SR
	src = (ph % 1.0) ** 3 - 0.25                         # buzzy glottal-ish pulse
	src += 0.15 * nz(n, rng)
	v = formant_voice(src, vowel, shift)
	env = np.minimum(1, np.maximum(0, t - h) / 0.02) * np.exp(-np.maximum(0, t - h) / (dur * 0.55))
	env *= np.where(t < dur, 1.0, np.exp(-(t - dur) / 0.02))
	breath = formant_voice(nz(n, rng), vowel, shift) * np.exp(-t / 0.04) * np.minimum(1, t / 0.006) * 0.7
	return v * env + breath


def hx_laugh():
	"""Snapjaw's laugh, broken: jaw clacks + a pitched-down synthetic 'ha-ha-ha-haaa', ring-modulated and crushed."""
	rng = R("laugh")
	out = np.zeros(nlen(3.6))
	starts = (0.0, 0.25, 0.47, 0.67, 0.86, 1.04)
	for i, s in enumerate(starts):
		m = nlen(0.12)
		tm = _t(m)
		clack = hp1(nz(m, rng), 900) * np.exp(-tm / 0.003) + 0.6 * np.sin(TAU * 1450 * tm) * np.exp(-tm / 0.02)
		place(out, clack, s, 0.6)
		f0 = 92 - i * 4
		place(out, _syll(f0, f0 * 0.86, 0.15, rng, "a"), s + 0.025, 1.0 - i * 0.06)
	place(out, _syll(84, 46, 1.25, rng, "a", h=0.06), 1.25, 1.0)
	place(out, _syll(60, 38, 0.8, rng, "o", h=0.04), 2.45, 0.5)
	t = _t(len(out))
	y = out * (0.55 + 0.45 * np.sin(TAU * 37 * t))          # robotic ring-mod
	y = np.tanh(3.0 * y / (np.max(np.abs(y)) + 1e-9))
	y = crush(y, hold=3, bits=6)
	y = lp1(lp1(y, 2600), 2600)
	y = room(y, 1.8, 0.33, seed=21, bright=0.5)
	return finish_sfx(y, loud=-13)


def hx_whisper():
	rng = R("whisper")
	dur = 3.4
	out = np.zeros(nlen(dur + 0.5))
	for voice in range(4):
		tt = 0.05 + voice * 0.31 + rng.uniform(0, 0.2)
		while tt < dur - 0.3:
			ln = rng.uniform(0.1, 0.28)
			n = nlen(ln)
			t = _t(n)
			if rng.random() < 0.3:
				seg = bq(nz(n, rng), "hp", rng.uniform(3800, 6000), 0.7) * 0.5
			else:
				seg = formant_voice(nz(n, rng), "aeou"[int(rng.integers(4))])
			env = np.sin(np.pi * t / ln) ** 2
			place(out, seg * env, tt, rng.uniform(0.4, 1.0) * (0.6 if voice % 2 else 1.0))
			tt += ln + rng.uniform(0.02, 0.18)
	t = _t(len(out))
	y = out * np.minimum(1, t / 0.4) * np.clip((dur + 0.3 - t) / 0.6, 0, 1)
	y = lp1(y, 7000)
	return finish_sfx(room(y, 2.0, 0.45, seed=17, bright=0.4), loud=-19)


def hx_static_burst():
	rng = R("static_burst")
	dur = 0.6
	n = nlen(dur)
	t = _t(n)
	w = nz(n, rng)
	w = crush(w / 3.0, hold=2, bits=5)
	crack = np.zeros(n)
	idx = rng.integers(0, n, 90)
	crack[idx] = rng.uniform(-1, 1, 90) * 3.0
	hum = 0.25 * np.sign(np.sin(TAU * 60 * t)) * 0.5
	env = np.minimum(1, t / 0.004) * np.where(t < 0.42, 1.0, np.exp(-(t - 0.42) / 0.05))
	y = (hp1(w, 250) + crack + hum) * env
	return finish_sfx(y, loud=-14)


def hx_standby():
	rng = R("standby")
	dur = 4.3
	n = nlen(dur)
	t = _t(n)
	w = bq(hp1(nz(n, rng), 180), "lp", 6500, 0.7)
	w *= 0.8 + 0.2 * np.sin(TAU * 0.7 * t)
	hum = sum(a * np.sin(TAU * f * t) for f, a in ((60, 1.0), (120, 0.6), (180, 0.4), (240, 0.25), (300, 0.12)))
	y = 0.55 * w + 0.12 * hum
	y *= np.minimum(1, t / 0.02) * np.clip((dur - t) / 0.35, 0, 1)
	return finish_sfx(y, loud=-19)


def hx_buzz():
	"""Failing bulb: clunk + 120 Hz sputtering buzz."""
	rng = R("buzz")
	dur = 0.85
	n = nlen(dur)
	t = _t(n)
	b = np.sign(np.sin(TAU * 120 * t)) * 0.5 + GA.osc_saw(240, n) * 0.4 + 0.2 * np.sin(TAU * 360 * t)
	b = bq(b, "lp", 3200, 0.8)
	gate = np.zeros(n)
	tt = 0.0
	while tt < dur:
		ln = rng.uniform(0.01, 0.05)
		on = rng.random() < (0.55 if tt < 0.45 else 0.9)
		a, e = nlen(tt), min(n, nlen(tt + ln))
		gate[a:e] = 1.0 if on else 0.05
		tt += ln
	gate = lp1(gate, 300)
	y = b * gate * np.clip((dur - t) / 0.2, 0, 1)
	clunk = GA._wood(n, rng, [(130, 1.0, 0.05), (380, 0.5, 0.02)], imp=0.6)
	ticks = np.zeros(n)
	for k in range(12):
		ticks[int(rng.integers(0, nlen(0.45)))] = rng.uniform(-1, 1) * 1.5
	y = 0.6 * y + 0.7 * clunk + hp1(ticks, 2000)
	return finish_sfx(room(y, 0.6, 0.12), loud=-17)


def hx_servo():
	rng = R("servo")
	dur = 0.5
	n = nlen(dur + 0.3)
	t = _t(n)
	g = np.clip(t / dur, 0, 1)
	f = 200 + 380 * g ** 0.7
	w = GA.osc_saw(f, n) * (0.6 + 0.4 * np.sign(np.sin(TAU * 55 * t)))
	w = bq(w, "bp", 1100, 1.5) * np.where(t < dur, np.minimum(1, t / 0.03), np.exp(-(t - dur) / 0.015))
	click = hp1(nz(n, rng), 2000) * bump(t, dur, 0.0005, 0.003) * 2.0 + 0.5 * np.sin(TAU * 2600 * t) * bump(t, dur, 0.0005, 0.03)
	return finish_sfx(room(w + click, 0.8, 0.15), loud=-18)


def hx_applause_stiff():
	"""Four claps in perfect, mechanical unison - then dead silence."""
	rng = R("applause")
	out = np.zeros(nlen(2.6))
	for k, s in enumerate((0.01, 0.45, 0.89, 1.33)):
		for v in range(34):
			m = nlen(0.12)
			tm = _t(m)
			fc = rng.uniform(900, 2600)
			c = bq(nz(m, rng), "bp", fc, 1.4) * np.exp(-tm / rng.uniform(0.006, 0.014))
			place(out, c, s + rng.uniform(-0.003, 0.003), rng.uniform(0.5, 1.0))
		m = nlen(0.1)
		clack = GA._wood(m, rng, [(1250, 1.0, 0.02), (2310, 0.6, 0.012), (3400, 0.3, 0.008)], imp=0.3)
		place(out, clack, s, 5.0)
	return finish_sfx(room(out, 1.7, 0.32, seed=27, bright=0.6), loud=-14)


def hx_turn():
	"""Every mannequin neck turning at once: unison creak, then one dry clack."""
	rng = R("turn")
	out = np.zeros(nlen(1.4))
	for v in range(16):
		m = nlen(0.3)
		x = stick_slip(m, rng, 90, 260, wobble=3.0)
		y = wood_body(x) * np.sin(np.pi * _t(m) / 0.3)
		place(out, y, rng.uniform(0.0, 0.02), rng.uniform(0.4, 1.0))
	m = nlen(0.2)
	clack = GA._wood(m, rng, [(380, 1.0, 0.03), (900, 0.7, 0.02), (1700, 0.4, 0.012)], imp=0.8)
	place(out, clack, 0.31, 3.0)
	return finish_sfx(room(out, 1.4, 0.3, seed=29), loud=-14)


def hx_sting():
	"""Dissonant orchestral-ish hit with a scraping, bowed cluster tail."""
	rng = R("sting")
	dur = 4.0
	n = nlen(dur)
	t = _t(n)
	hit = sweep_sin(40 + 90 * np.exp(-t / 0.06), n) * np.exp(-t / 0.6)
	cl = np.zeros(n)
	for m in (48, 49, 54, 55, 60, 61, 66):
		f = GA.midi_hz(m) * (1 + rng.uniform(-0.003, 0.003))
		vib = 1 + 0.004 * np.sin(TAU * rng.uniform(4.5, 6.0) * t)
		cl += GA.osc_saw(f * vib, n, rng.random())
	cl = bq(cl, "lp", 2600, 0.8) * (np.minimum(1, t / 0.01) * (0.35 + 0.65 * np.exp(-t / 0.5))) * np.clip((dur - t) / 1.6, 0, 1)
	scrape = bq_sweep(nz(n, rng), "bp", 3000 - 1800 * np.clip(t / dur, 0, 1), 4.0, chunk=128) * np.exp(-t / 1.4) * (0.7 + 0.3 * np.sin(TAU * 31 * t))
	y = np.tanh(1.4 * (1.0 * hit + 0.4 * cl / 4 + 0.35 * scrape))
	return finish_sfx(room(y, 2.6, 0.4, seed=31, bright=0.7), loud=-12)


def hx_musicbox():
	"""A music box winding down: the comb plucks slower and flatter, then the spring gives out."""
	out = np.zeros(nlen(6.0))
	notes = ((0.0, 84, 0), (0.32, 79, -8), (0.68, 75, -20), (1.12, 74, -35), (1.66, 71, -55), (2.36, 72, -80), (3.3, 67, -120))
	for s, m, cents in notes:
		w = GA.render_note("musicbox", GA.midi_hz(m + cents / 100.0), 0.5)
		place(out, w, s, 0.9)
	rng = R("musicbox")
	m = nlen(0.1)
	tm = _t(m)
	place(out, hp1(nz(m, rng), 1500) * np.exp(-tm / 0.004) * 0.6, 4.1)
	return finish_sfx(room(out, 2.6, 0.42, seed=33, bright=0.6), loud=-15)


def hx_thunder():
	rng = R("thunder")
	dur = 4.0
	n = nlen(dur)
	t = _t(n)
	crack = bq(nz(n, rng), "bp", 2600, 0.8) * bump(t, 0.0, 0.003, 0.06)
	rum = lp1(lp1(nz(n, rng), 160), 160)
	mod = np.zeros(n)
	for k in range(9):
		mod += rng.uniform(0.3, 1.0) * bump(t, rng.uniform(0.02, 1.8), rng.uniform(0.05, 0.3), rng.uniform(0.3, 1.0))
	y = 0.5 * crack + 3.0 * rum * mod * np.clip((dur - t) / 1.5, 0, 1)
	return finish_sfx(room(y, 2.5, 0.3, seed=35, bright=0.3), loud=-13)


def hx_drip():
	rng = R("drip")
	n = nlen(0.12)
	t = _t(n)
	plip = sweep_sin(520 + 1300 * np.clip(t / 0.03, 0, 1), n) * np.exp(-t / 0.018) * np.minimum(1, t / 0.0008)
	tok = sweep_sin(180 + 120 * np.exp(-t / 0.01), n) * np.exp(-t / 0.02) * 0.5
	y = room(plip + tok, 2.2, 0.55, seed=37, bright=0.35)
	return finish_sfx(y, loud=-18)


def hx_splatter():
	rng = R("splatter")
	out = np.zeros(nlen(1.8))
	n = nlen(0.4)
	t = _t(n)
	thump = sweep_sin(48 + 70 * np.exp(-t / 0.03), n) * np.exp(-t / 0.12)
	place(out, thump, 0.0, 1.0)
	for k in range(70):
		s = rng.uniform(0.0, 0.65) ** 1.6
		m = nlen(rng.uniform(0.015, 0.05))
		tm = _t(m)
		g = bq(nz(m, rng), "bp", rng.uniform(280, 1300), 3.0) * np.sin(np.pi * tm / (m / SR))
		place(out, g, s, rng.uniform(0.2, 0.7) * (1 - s))
	for k in range(6):
		s = rng.uniform(0.3, 1.1)
		m = nlen(0.06)
		tm = _t(m)
		place(out, sweep_sin(rng.uniform(400, 700) * (1 + 2.0 * tm / 0.06), m) * np.exp(-tm / 0.012), s, 0.25)
	y = lp1(out, 2600)
	return finish_sfx(room(y, 1.1, 0.22, seed=39, bright=0.4), loud=-14)


def hx_wind():
	rng = R("wind")
	dur = 7.0
	n = nlen(dur)
	t = _t(n)
	w = nz(n, rng)
	a = bq_sweep(w, "bp", 380 + 260 * np.sin(TAU * 0.13 * t) + 120 * np.sin(TAU * 0.41 * t), 4.0, chunk=256)
	b = bq_sweep(w, "bp", 900 + 400 * np.sin(TAU * 0.09 * t + 1.0), 6.0, chunk=256)
	env = np.sin(np.pi * t / dur) ** 1.5 * (0.7 + 0.3 * np.sin(TAU * 0.3 * t))
	y = (a + 0.5 * b) * env
	return finish_sfx(lp1(y, 3000), loud=-19)


def hx_end_tone():
	dur = 2.8
	n = nlen(dur)
	t = _t(n)
	f = 1000 * (1 + 0.003 * np.sin(TAU * 0.8 * t) + 0.0015 * np.sin(TAU * 5.5 * t))
	y = sweep_sin(f, n) * (0.9 + 0.1 * np.sin(TAU * 0.5 * t))
	y *= np.minimum(1, t / 0.02) * np.clip((dur - t) / 0.4, 0, 1)
	return finish_sfx(y, loud=-22)


SFX = {
	"hx_heartbeat": hx_heartbeat, "hx_thud": hx_thud, "hx_slam": hx_slam, "hx_creak": hx_creak, "hx_chain": hx_chain,
	"hx_blade": hx_blade, "hx_drone_hit": hx_drone_hit, "hx_swell": hx_swell, "hx_laugh": hx_laugh,
	"hx_whisper": hx_whisper, "hx_static_burst": hx_static_burst, "hx_standby": hx_standby, "hx_buzz": hx_buzz,
	"hx_servo": hx_servo, "hx_applause_stiff": hx_applause_stiff, "hx_turn": hx_turn, "hx_sting": hx_sting,
	"hx_musicbox": hx_musicbox, "hx_thunder": hx_thunder, "hx_drip": hx_drip, "hx_splatter": hx_splatter,
	"hx_wind": hx_wind, "hx_end_tone": hx_end_tone,
}


# =====================================================================================  music
LOOP_S = 60.0


def music_execution_horror():
	"""3/4 at 60 bpm, 20 bars = 60 s. Sections (music time):
	0-12  music-box lullaby (out of tune) over beating C/Db drones, clockwork ticks
	12-24 lullaby answer + the old carnival waltz crawling far away on a calliope
	24-36 music box drags on a stretching tape, heartbeats, high whistling cluster
	36-48 low, slow reprise an octave down, heartbeat + drone swell
	48-60 near silence: drones, wind, a few stray notes (loops back to the start)"""
	L = nlen(LOOP_S)
	T = L / SR
	GA._LOOP_T = T
	t = np.arange(L) / SR
	rng = R("music")

	def q(f):
		return max(1.0, round(f * T)) / T

	def circ_add(dst, src, t0, gain=1.0):
		s = int(round(t0 * SR)) % L
		src = np.asarray(src, float) * gain
		while len(src):
			k = min(L - s, len(src))
			dst[s:s + k] += src[:k]
			src = src[k:]
			s = 0

	def per_env(points):
		"""Loop-periodic piecewise-linear envelope from (time, value) points."""
		ts = [p[0] for p in points] + [points[0][0] + T]
		vs = [p[1] for p in points] + [points[0][1]]
		return np.interp(t, ts, vs, period=None)

	def level(x, target_db):
		return x * undb(target_db) / max(rms(x), 1e-9)

	# --- drones: C1 + Db1 beating, G1, a tritone F#2 ghost
	dr = np.zeros(L)
	for f, a in ((32.70, 1.0), (34.65, 0.8), (49.0, 0.45), (92.5, 0.25)):
		dr += a * GA.osc_saw(q(f), L, rng.random())
	cut = 150 + 110 * (0.5 + 0.5 * np.sin(TAU * q(1 / 15.0) * t))
	dr = GA.circ(dr, lambda s: bq_sweep(s, "lp", np.resize(cut, len(s)), 1.6, chunk=256), pad=1.0)
	dr *= per_env([(0, 0.55), (12, 0.7), (24, 0.85), (36, 1.0), (47, 1.0), (52, 0.6)])
	sub = np.sin(TAU * q(32.7) * t) * 0.6
	drones = level(dr + sub * per_env([(0, 0.5), (30, 1.0), (48, 0.8)]), -21)

	# --- music box (dry, gets the tape treatment)
	MB = []

	def mel(t0, text, oct_=0, vel=0.9, beat=1.0):
		ev, _ = GA.parse_melody(text, 3)
		for b, d, m in ev:
			MB.append((t0 + b * beat, m + oct_, vel))

	A = "g4:1 c5 eb5 | d5:1.5 c5:.5 b4:1 | c5:1 g4 ab4 | g4:3"
	A2 = "g4:1 c5 eb5 | f5:1.5 eb5:.5 d5:1 | eb5:1 c5 f#4 | g4:2 r:1"
	HI = "c6:1 r:1 b5:1 | db6:2 r:1 | g5:1 f#5 g5 | r:3"
	mel(0.0, A, 12)
	mel(12.0, A2, 12)
	mel(24.0, HI, 0, 0.8)
	mel(36.0, A, 0, 0.9)
	mel(48.0, "c5:3 | r:3 | b4:1 r:2 | r:3", 0, 0.6)
	box = np.zeros(L)
	for s, m, v in MB:
		det = rng.uniform(-28, 28) / 100.0
		w = GA.render_note("musicbox", GA.midi_hz(m + det), 0.6)
		circ_add(box, w, s + rng.uniform(-0.015, 0.015), v * rng.uniform(0.85, 1.0))
	# clockwork ticks (sections 1-2)
	ticks = np.zeros(L)
	for k in range(24):
		m = nlen(0.03)
		tm = _t(m)
		tk = bq(rng.standard_normal(m), "bp", 3200, 4) * np.exp(-tm / 0.003)
		circ_add(ticks, tk, k * 1.0 + 0.5, 0.7 if k % 3 == 0 else 0.4)
	box = level(box, -20) + level(ticks, -36)

	# --- far-away calliope crawling through the old carnival waltz motif (bars 5-8)
	INTRO = "c5:.5 b4 c5 b4 c5 b4 | c5:.5 b4 c5 db5 c5 b4 | g5:.5 f#5 f5 e5 eb5 d5 | c#5:.5 c5 b4:1 r:1"
	cal = np.zeros(L)
	ev, _ = GA.parse_melody(INTRO, 3)
	for b, d, m in ev:
		for det in (-0.22, 0.0, 0.17):
			w = GA.render_note("organ", GA.midi_hz(m - 1 + det), d * 0.9)
			circ_add(cal, w, 12.0 + b, 0.5)
	cal = GA.circ(cal, lambda s: lp1(lp1(s, 1100), 1100), pad=0.5)
	cal = level(cal, -27)

	# --- tape: slow wow everywhere + a long pitch drag on the music box in 24-36
	def warble(x, depth_s, rate, extra=None):
		d = depth_s * (0.5 + 0.5 * np.sin(TAU * q(rate) * t)) + 0.0004 * np.sin(TAU * q(6.1) * t)
		if extra is not None:
			d = d + extra
		idx = np.arange(L) - d * SR
		i0 = np.floor(idx).astype(np.int64)
		fr = idx - i0
		return x[i0 % L] * (1 - fr) + x[(i0 + 1) % L] * fr

	drag = np.zeros(L)
	up = (t >= 24.0) & (t < 31.0)
	drag[up] = 0.32 * (0.5 - 0.5 * np.cos(np.pi * (t[up] - 24.0) / 7.0))
	dn = (t >= 31.0) & (t < 40.0)
	drag[dn] = 0.32 * (0.5 + 0.5 * np.cos(np.pi * (t[dn] - 31.0) / 9.0))
	box = warble(box, 0.006, 0.31, drag)
	cal = warble(cal, 0.012, 0.23)

	# --- heartbeats (24-47 s), slow and muffled
	hb = np.zeros(L)
	k = 24.0
	while k < 47.0:
		w = GA.render_note("heart", 60.0, 0.3)
		circ_add(hb, lp1(w, 260), k, 1.0)
		k += 1.5 if k < 36 else 1.25
	hb = level(hb, -24)

	# --- high whistling cluster (24-36), wind throughout
	wh = np.zeros(L)
	for f in (1480.0, 2093.0, 2217.5):
		wh += np.sin(TAU * q(f) * t + rng.random() * TAU)
	wh *= (0.7 + 0.3 * np.sin(TAU * q(5.3) * t)) * per_env([(0, 0.0), (22, 0.0), (28, 1.0), (35, 1.0), (38, 0.0)])
	wh = level(wh, -34) if np.any(wh) else wh
	wn = GA.circ(rng.standard_normal(L), lambda s: bq_sweep(s, "bp", np.resize(500 + 300 * np.sin(TAU * q(0.11) * t), len(s)), 3.0, chunk=256), pad=1.0)
	wn = level(wn * per_env([(0, 0.7), (20, 1.0), (40, 0.8), (50, 1.0)]), -30)

	# --- reverse swells into 12, 24, 36
	sw = np.zeros(L)
	for at in (12.0, 24.0, 36.0):
		w = GA.render_note("swell", 0.0, 2.5)
		circ_add(sw, w, at - 2.5, 1.0)
	sw = level(sw, -31)

	dry = drones + box + cal + hb + wh + wn + sw
	send = 0.6 * box + 0.9 * cal + 0.3 * hb + 0.4 * wh + 0.2 * sw
	wet = GA.circ_conv(send, GA.reverb_ir(3.8, seed=4242, bright=0.6)) * 0.55
	mix = dry + wet
	y, over = GA.master_music(mix)
	GA._LOOP_T = None
	return y


SONGS = {"execution_horror": music_execution_horror}


def main():
	ids = sys.argv[1:] or (list(SONGS) + list(SFX))
	res = []
	for i in ids:
		if i in SONGS:
			y = SONGS[i]()
			path = os.path.join(MUSIC_DIR, i + ".wav")
			GA.write_wav(path, y, seed=zlib.crc32(i.encode()))
			res.append(GA.analyze(path, True))
		elif i in SFX:
			y = SFX[i]()
			path = os.path.join(SFX_DIR, i + ".wav")
			GA.write_wav(path, y, seed=zlib.crc32(i.encode()))
			res.append(GA.analyze(path, False))
		else:
			sys.exit("unknown id %r (music: %s; sfx: %s)" % (i, ", ".join(SONGS), ", ".join(SFX)))
		print("  rendered", i)
	GA.print_table(res)


if __name__ == "__main__":
	main()
