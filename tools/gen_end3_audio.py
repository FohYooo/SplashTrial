#!/usr/bin/env python3
"""
SPLASH TRIAL - Case 3 endings audio (SPOILERS: the Case 3 execution, wrong-vote ending and Caiman's kill).
Python standard library only; the DSP core is shared with tools/gen_exec2_audio.py.

Renders 16-bit PCM, 32 kHz, mono WAV files (same format and loudness targets as the other generators):

    audio/music/execution_press.wav   34 s. "STOP PRESS" (execution3_screen.gd). Music time m = screen time - 4:
                                        m  0-12  low drone, a slow mechanical heartbeat and typewriter ticks
                                        m 12-24  the ostinato tightens, a sour high cluster creeps in
                                        m 24-34  the press's rhythm doubles, everything rises (the screen cuts it at the kill)
    audio/music/execution_lineup.wav  24 s seamless loop. "THE LINE-UP" (gameover3_screen.gd): a cold drone and a
                                      dripping pulse under the roll call
    audio/sfx/sp_*.wav   press, hiss, flash, type, bell, crush, run, paper
    audio/sfx/wv_*.wav   gate, bell
    audio/sfx/ck_*.wav   swing, catch, bite, scream, clatter, ring

Everything is synthesized (no samples, no real voices) and deterministic (fixed seeds).

    python3 tools/gen_end3_audio.py              # render everything
    python3 tools/gen_end3_audio.py sp_crush     # render only these ids
"""
import math
import os
import random
import sys
import zlib

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from gen_exec2_audio import (SR, TAU, MUSIC_DIR, SFX_DIR, nlen, zeros, undb, add_into, scale, lp1, hp1, bq,  # noqa: E402
	resonators, noise, env_ad, mul, damped, sine, sweep, fade_in, fade_out, softclip, reverb, finish_sfx, rms,
	write_wav, click_tpl, formant, wood, CEIL)


def R(name):
	return random.Random(zlib.crc32(("end3/" + name).encode()))


def metal(n, rng, f0=220.0, dec=0.5, amp=1.0, partials=(1.0, 1.58, 2.37, 3.98, 5.1, 6.7)):
	"""Struck iron: a few inharmonic damped partials and a noisy strike."""
	out = zeros(n)
	for k, p in enumerate(partials):
		add_into(out, damped(f0 * p * rng.uniform(0.99, 1.01), 1.0 / (1 + k * 0.6), dec / (1 + k * 0.45), n), 0)
	m = min(n, nlen(0.03))
	strike = bq(mul(noise(m, rng), env_ad(m, 0.0002, 0.004)), "hp", 1500, 0.7)
	add_into(out, strike, 0, 1.2)
	return scale(out, amp)


def sub_boom(dur, f_hi=90.0, f_lo=32.0, tau=0.06, dec=0.5):
	n = nlen(dur)
	return mul(sweep(lambda t: f_lo + (f_hi - f_lo) * math.exp(-t / tau), n), env_ad(n, 0.0015, dec))


def cracks(dur, rng, count, f_lo=900, f_hi=2600, spread=0.12):
	"""A burst of short, dry snaps."""
	out = zeros(nlen(dur))
	for _ in range(count):
		t = rng.uniform(0, spread) ** 1.4
		add_into(out, click_tpl(rng, rng.uniform(f_lo, f_hi), 0.002, 0.008, rng.uniform(0.4, 1.0), 0.05), nlen(t))
	return out


def wet(dur, rng, fc0=500, fc1=180, amp=1.0):
	"""A wet squelch: low noise through a falling band-pass."""
	n = nlen(dur)
	nz = noise(n, rng)
	out = zeros(n)
	step = nlen(0.02)
	for s in range(0, n, step):
		t = s / SR
		fc = fc1 + (fc0 - fc1) * math.exp(-t / (dur * 0.3))
		seg = bq(nz[s:s + step * 2], "bp", fc, 1.4)
		add_into(out, [v * 0.5 for v in seg], s)
	return mul(scale(lp1(out, 1400), amp), env_ad(n, 0.003, dur * 0.35))


def hiss(dur, rng, fc=4200, a=0.05, d=0.4):
	n = nlen(dur)
	return mul(bq(noise(n, rng), "hp", fc, 0.6), env_ad(n, a, d))


# ===================================================================================== STOP PRESS
def sp_press():
	"""One stroke of the giant press: a steam hiss, iron clanking home, a deep boom through the floor."""
	rng = R("press")
	out = zeros(nlen(3.0))
	add_into(out, hiss(0.5, rng, 3600, 0.01, 0.18), 0, 0.45)
	add_into(out, metal(nlen(1.6), rng, 96, 0.9, 1.0), nlen(0.2))
	add_into(out, metal(nlen(0.8), rng, 210, 0.35, 0.6), nlen(0.21))
	add_into(out, sub_boom(2.0, 80, 30, 0.07, 0.55), nlen(0.2), 1.6)
	out = [math.tanh(1.4 * v) for v in out]
	return finish_sfx(reverb(out, 2.4, 0.4, 1.3, damp=0.5, seed=31), -11)


def sp_hiss():
	"""The hydraulics breathing out before a stroke."""
	rng = R("hiss")
	n = nlen(1.4)
	h = bq(noise(n, rng), "bp", 3000, 0.5)
	e = [min(1.0, (i / SR) / 0.15) * math.exp(-max(0.0, i / SR - 0.5) / 0.35) * (0.8 + 0.2 * math.sin(TAU * 23 * i / SR)) for i in range(n)]
	return finish_sfx(reverb(mul(h, e), 1.2, 0.25, 0.8, seed=32), -18)


def sp_flash():
	"""An old flashbulb: a charging whine, a glassy pop, a bright fizz."""
	rng = R("flash")
	out = zeros(nlen(0.9))
	w = nlen(0.16)
	add_into(out, mul(sweep(lambda t: 2200 + 5200 * t / 0.16, w), env_ad(w, 0.12, 0.05)), 0, 0.1)
	m = nlen(0.35)
	pop = mul(noise(m, rng), env_ad(m, 0.0003, 0.012))
	add_into(out, bq(pop, "hp", 900, 0.6), w, 1.0)
	add_into(out, mul(sine(110, m), env_ad(m, 0.001, 0.03)), w, 0.6)
	add_into(out, hiss(0.5, rng, 6000, 0.002, 0.08), w, 0.25)
	for _ in range(6):
		add_into(out, damped(rng.uniform(3800, 6200), 0.12, 0.02, nlen(0.08)), w + nlen(rng.uniform(0.02, 0.2)))
	return finish_sfx(reverb(out, 1.4, 0.3, 0.9, seed=33), -15)


def sp_type():
	"""A newsroom of typewriters at once: dense, uneven key strikes."""
	rng = R("type")
	out = zeros(nlen(1.8))
	t = 0.0
	while t < 1.65:
		t += rng.uniform(0.02, 0.11)
		k = click_tpl(rng, rng.uniform(1600, 3400), 0.002, 0.012, rng.uniform(0.4, 1.0), 0.06)
		k = [a + b for a, b in zip(k, wood(mul(noise(len(k), rng), env_ad(len(k), 0.0002, 0.004)), 0.9))]
		add_into(out, k, nlen(t), 0.8)
	return finish_sfx(reverb(out, 1.0, 0.22, 0.8, seed=34), -16)


def sp_bell():
	"""The carriage bell, then the carriage slammed back."""
	rng = R("bell")
	out = zeros(nlen(1.3))
	n = nlen(1.2)
	add_into(out, damped(2093, 0.7, 0.5, n), 0)
	add_into(out, damped(5650, 0.25, 0.12, n), 0)
	add_into(out, damped(3140, 0.2, 0.2, n), 0)
	z = nlen(0.25)
	zip_ = bq(mul(noise(z, rng), env_ad(z, 0.15, 0.05)), "bp", 1400, 1.0)
	add_into(out, zip_, nlen(0.35), 0.7)
	add_into(out, metal(nlen(0.3), rng, 420, 0.08, 0.6), nlen(0.6))
	return finish_sfx(out, -15)


def sp_crush():
	"""The plate comes all the way down: iron, then bone, then something wet. Brutal and short."""
	rng = R("crush")
	out = zeros(nlen(3.2))
	add_into(out, metal(nlen(1.8), rng, 80, 0.8, 1.2), 0)
	add_into(out, sub_boom(2.4, 110, 26, 0.05, 0.7), 0, 2.0)
	add_into(out, cracks(0.4, rng, 26, 700, 2400, 0.14), nlen(0.006), 1.3)
	add_into(out, wet(0.9, rng, 700, 160, 1.6), nlen(0.02))
	add_into(out, wet(0.6, rng, 400, 120, 1.0), nlen(0.16))
	out = [math.tanh(2.2 * v) for v in out]
	return finish_sfx(reverb(out, 2.2, 0.36, 1.2, damp=0.55, seed=35), -9)


def sp_run():
	"""The press running on by itself: thump, clack, rollers - one 2.4 s cycle, scheduled over and over."""
	rng = R("run")
	dur = 2.4
	out = zeros(nlen(dur))
	n = nlen(dur)
	roll = lp1(bq(noise(n, rng), "bp", 220, 0.7), 900)
	add_into(out, [v * (0.5 + 0.5 * math.sin(TAU * i / SR / 0.6)) for i, v in enumerate(roll)], 0, 0.6)
	for k in range(4):
		t = k * 0.6
		add_into(out, sub_boom(0.4, 70, 40, 0.03, 0.12), nlen(t), 0.9)
		add_into(out, metal(nlen(0.3), rng, 330, 0.06, 0.45), nlen(t + 0.3))
	return finish_sfx(out, -16)


def sp_paper():
	"""A printed sheet shot out of the press, fluttering down."""
	rng = R("paper")
	n = nlen(0.7)
	nz = bq(noise(n, rng), "bp", 2600, 0.5)
	e = [math.exp(-(i / SR) / 0.25) * (0.6 + 0.4 * abs(math.sin(TAU * 17 * i / SR))) for i in range(n)]
	return finish_sfx(mul(nz, e), -19)


def music_execution_press():
	"""34 s, m = screen time - 4. Drone, mechanical pulse, typewriter ticks, a sour cluster; rises to the stroke."""
	rng = R("music_press")
	dur = 34.0
	n = nlen(dur)
	out = zeros(n)
	# the drone: detuned low saws, slowly breathing
	for f0, g in ((41.2, 0.5), (41.9, 0.45), (61.7, 0.25)):
		ph = 0.0
		buf = [0.0] * n
		for i in range(n):
			ph = (ph + f0 / SR) % 1.0
			buf[i] = (ph * 2.0 - 1.0)
		buf = lp1(lp1(buf, 240), 240)
		for i in range(n):
			t = i / SR
			out[i] += g * buf[i] * (0.7 + 0.3 * math.sin(TAU * 0.07 * t + f0))
	# the press's heartbeat: a thump every beat, the beat tightening from 1.5 s to 0.6 s
	t = 0.6
	while t < dur - 0.3:
		k = t / dur
		add_into(out, sub_boom(0.5, 75, 38, 0.03, 0.14), nlen(t), 0.9 + 0.5 * k)
		add_into(out, metal(nlen(0.25), rng, 260 + 40 * k, 0.05, 0.25 + 0.2 * k), nlen(t + 0.04))
		t += 1.5 - 0.9 * min(1.0, max(0.0, (t - 10.0) / 20.0))
	# typewriter ticks, scattered, thinning out as the stroke nears
	t = 0.3
	while t < 26.0:
		t += rng.uniform(0.08, 0.5)
		add_into(out, click_tpl(rng, rng.uniform(1800, 3200), 0.002, 0.01, 0.25, 0.05), nlen(t))
	# the sour high cluster, creeping in from m 12, swelling to the end
	for f in (880.0, 932.3, 987.8, 1046.5):
		buf = sine(f, n)
		for i in range(n):
			tt = i / SR
			g = max(0.0, (tt - 12.0) / 22.0) ** 1.6
			out[i] += buf[i] * 0.05 * g * (0.6 + 0.4 * math.sin(TAU * (5.5 + f / 400.0) * tt))
	# a riser into the stroke (m 26 - 34)
	r0 = nlen(26.0)
	rise = sweep(lambda tt: 120 + 900 * (tt / 8.0) ** 2, nlen(8.0))
	add_into(out, mul(rise, [min(1.0, (i / SR) / 8.0) ** 2 * 0.18 for i in range(len(rise))]), r0)
	add_into(out, mul(bq(noise(nlen(8.0), rng), "bp", 1600, 0.6), [((i / SR) / 8.0) ** 3 * 0.25 for i in range(nlen(8.0))]), r0)
	y = reverb(out, 2.8, 0.35, 1.3, damp=0.5, seed=36)
	y = fade_out(fade_in(y, 300), 200)
	g = undb(-18.0) / max(1e-9, rms(y))
	y = [softclip(v * g, 0.7) for v in y]
	return y


# ===================================================================================== THE LINE-UP
def wv_gate():
	"""A spiked gate dropped on its chain: the chain runs out, iron slams home, and something gives under it."""
	rng = R("gate")
	out = zeros(nlen(2.8))
	t = 0.0
	gap = 0.06
	while t < 0.32:
		add_into(out, metal(nlen(0.12), rng, rng.uniform(900, 1400), 0.03, 0.35), nlen(t))
		t += gap
		gap *= 0.82
	s = nlen(0.34)
	add_into(out, metal(nlen(1.8), rng, 120, 0.9, 1.3), s)
	add_into(out, metal(nlen(1.2), rng, 610, 0.4, 0.5), s)
	add_into(out, sub_boom(2.0, 100, 30, 0.05, 0.5), s, 1.6)
	add_into(out, cracks(0.3, rng, 16, 700, 2200, 0.1), s + nlen(0.005), 1.0)
	add_into(out, wet(0.7, rng, 600, 150, 1.3), s + nlen(0.02))
	out = [math.tanh(1.8 * v) for v in out]
	return finish_sfx(reverb(out, 2.0, 0.38, 1.2, damp=0.5, seed=41), -10)


def wv_bell():
	"""The Gaol's roll-call bell: one cold, cracked clang."""
	rng = R("wbell")
	n = nlen(3.2)
	out = zeros(n)
	for p, g, d in ((1.0, 1.0, 1.6), (2.02, 0.5, 1.1), (2.76, 0.45, 0.8), (4.07, 0.3, 0.5), (5.43, 0.25, 0.35), (6.9, 0.12, 0.2)):
		add_into(out, damped(262.0 * p * rng.uniform(0.995, 1.005), g, d, n), 0)
	add_into(out, damped(266.0, 0.6, 1.5, n), 0)
	add_into(out, bq(mul(noise(nlen(0.05), rng), env_ad(nlen(0.05), 0.0002, 0.006)), "hp", 1200, 0.7), 0, 0.8)
	return finish_sfx(reverb(out, 2.6, 0.3, 1.3, seed=42), -14)


def music_execution_lineup():
	"""24 s seamless loop: a cold drone, a dripping pulse."""
	rng = R("music_lineup")
	dur = 24.0
	n = nlen(dur)
	out = zeros(n)
	for f0, g in ((55.0, 0.5), (55.4, 0.4), (82.4, 0.18), (116.5, 0.08)):
		buf = sine(f0, n)
		for i in range(n):
			out[i] += g * buf[i] * (0.75 + 0.25 * math.sin(TAU * (1.0 / dur) * 2 * i / SR + f0))
	for k in range(16):
		t = k * 1.5
		add_into(out, sub_boom(0.6, 62, 44, 0.04, 0.2), nlen(t), 0.6, wrap=True)
	for k in range(24):
		t = rng.uniform(0, dur)
		d = nlen(0.06)
		f0 = rng.uniform(900, 1500)
		add_into(out, mul(sweep(lambda tt, f0=f0: f0 * (1 + 1.8 * tt / 0.06), d), env_ad(d, 0.001, 0.015)), nlen(t), 0.12, wrap=True)
	y = reverb(out, 3.2, 0.4, 1.4, damp=0.5, seed=43, circular=True)
	g = undb(-20.0) / max(1e-9, rms(y))
	return [softclip(v * g, 0.7) for v in y]


# ===================================================================================== CAIMAN'S KILL
def ck_swing():
	"""A cleaver swung hard: air torn open."""
	rng = R("swing")
	n = nlen(0.6)
	nz = noise(n, rng)
	out = zeros(n)
	step = nlen(0.01)
	for s in range(0, n, step):
		t = s / SR
		fc = 500 + 2600 * min(1.0, t / 0.28)
		add_into(out, [v * 0.5 for v in bq(nz[s:s + step * 2], "bp", fc, 2.0)], s)
	e = [math.sin(math.pi * min(1.0, (i / SR) / 0.42)) ** 2 for i in range(n)]
	return finish_sfx(mul(out, e), -14)


def ck_catch():
	"""Caught mid-swing: a hard, bony clack and the grip closing."""
	rng = R("catch")
	out = zeros(nlen(0.9))
	add_into(out, click_tpl(rng, 1200, 0.003, 0.02, 1.0, 0.1), 0)
	add_into(out, wood(mul(noise(nlen(0.2), rng), env_ad(nlen(0.2), 0.0003, 0.008)), 0.7), 0, 1.2)
	add_into(out, sub_boom(0.5, 120, 50, 0.02, 0.12), 0, 1.0)
	add_into(out, metal(nlen(0.6), rng, 1180, 0.25, 0.3), nlen(0.01))
	return finish_sfx(reverb(out, 1.4, 0.25, 1.0, seed=51), -11)


def ck_bite():
	"""The jaws close: a huge clap of teeth, bone giving way, a wet tearing, a mechanical growl under it all."""
	rng = R("bite")
	out = zeros(nlen(2.6))
	add_into(out, click_tpl(rng, 900, 0.004, 0.03, 1.5, 0.15), 0)
	add_into(out, sub_boom(2.0, 140, 28, 0.04, 0.6), 0, 2.2)
	add_into(out, cracks(0.5, rng, 34, 600, 2400, 0.2), nlen(0.004), 1.5)
	add_into(out, wet(1.1, rng, 800, 140, 1.8), nlen(0.03))
	add_into(out, wet(0.7, rng, 500, 120, 1.3), nlen(0.45))
	add_into(out, cracks(0.4, rng, 14, 500, 1600, 0.12), nlen(0.46), 1.1)
	# the growl: a crushed low buzz through an 'o'
	m = nlen(1.6)
	ph = 0.0
	src = [0.0] * m
	for i in range(m):
		t = i / SR
		ph = (ph + (52 + 6 * math.sin(TAU * 7 * t)) / SR) % 1.0
		src[i] = ph * 2 - 1 + 0.3 * (rng.random() * 2 - 1)
	gr = mul(formant(src, "o", 0.55), env_ad(m, 0.05, 0.6))
	add_into(out, [math.tanh(3 * v) for v in gr], nlen(0.1), 0.5)
	out = [math.tanh(2.0 * v) for v in out]
	return finish_sfx(reverb(out, 1.8, 0.3, 1.1, damp=0.55, seed=52), -8)


def _scream(f0, dur, rng, vowel="a", shift=1.0, rise=1.25):
	n = nlen(dur)
	src = [0.0] * n
	ph = 0.0
	for i in range(n):
		t = i / SR
		k = min(1.0, t / 0.25)
		f = f0 * (1 + (rise - 1) * k) * (1 + 0.03 * math.sin(TAU * 6.2 * t) + 0.01 * (rng.random() - 0.5))
		ph = (ph + f / SR) % 1.0
		src[i] = (ph ** 2 - 0.33) + 0.35 * (rng.random() * 2 - 1)
	v = formant(src, vowel, shift)
	e = [min(1.0, (i / SR) / 0.06) * (1.0 if i / SR < dur * 0.7 else math.exp(-(i / SR - dur * 0.7) / (dur * 0.12))) for i in range(n)]
	return mul(v, e)


def ck_scream():
	"""Everyone at once: screams over each other, breaking off."""
	rng = R("scream")
	out = zeros(nlen(2.6))
	for (t, f0, d, vw, sh) in ((0.0, 620, 1.8, "a", 1.25), (0.05, 470, 1.6, "a", 1.1), (0.12, 760, 1.4, "e", 1.3), (0.2, 330, 1.7, "o", 1.0),
			(0.3, 540, 1.2, "a", 1.2), (0.42, 880, 1.0, "e", 1.35), (0.5, 260, 1.5, "o", 0.9)):
		add_into(out, _scream(f0, d, rng, vw, sh), nlen(t), rng.uniform(0.6, 1.0))
	add_into(out, hiss(2.2, rng, 2500, 0.05, 0.9), 0, 0.15)
	out = [math.tanh(1.6 * v) for v in out]
	return finish_sfx(reverb(out, 1.6, 0.3, 1.1, seed=53), -11)


def ck_clatter():
	"""The cleaver hits the marble, bounces, skids and spins to a stop."""
	rng = R("clatter")
	out = zeros(nlen(2.4))
	t, gap, amp = 0.0, 0.26, 1.0
	for _ in range(5):
		add_into(out, metal(nlen(0.5), rng, 1860, 0.18, amp, (1.0, 2.13, 2.9, 3.71)), nlen(t))
		t += gap
		gap *= 0.62
		amp *= 0.7
	# the spin: a fast rattle slowing down
	rate = 30.0
	while t < 2.1 and rate > 4:
		add_into(out, metal(nlen(0.08), rng, 2400, 0.02, 0.18 * rate / 30.0, (1.0, 1.7)), nlen(t))
		t += 1.0 / rate
		rate *= 0.94
	return finish_sfx(reverb(out, 1.8, 0.3, 1.2, seed=54), -15)


def ck_ring():
	"""The ringing in your ears after: a thin high tone, fading out to nothing."""
	n = nlen(6.0)
	a = sine(5200, n)
	b = sine(5237, n)
	e = [min(1.0, (i / SR) / 0.3) * math.exp(-(i / SR) / 1.8) for i in range(n)]
	return finish_sfx(mul([x + y for x, y in zip(a, b)], e), -26)


SFX = {f.__name__: f for f in (sp_press, sp_hiss, sp_flash, sp_type, sp_bell, sp_crush, sp_run, sp_paper,
	wv_gate, wv_bell, ck_swing, ck_catch, ck_bite, ck_scream, ck_clatter, ck_ring)}
MUSIC = {"execution_press": music_execution_press, "execution_lineup": music_execution_lineup}


def main():
	want = set(sys.argv[1:])
	for name, fn in SFX.items():
		if want and name not in want:
			continue
		y = fn()
		p = os.path.join(SFX_DIR, name + ".wav")
		write_wav(p, y, zlib.crc32(name.encode()))
		print("wrote", os.path.relpath(p), "%.2f s" % (len(y) / SR))
	for name, fn in MUSIC.items():
		if want and name not in want:
			continue
		y = fn()
		p = os.path.join(MUSIC_DIR, name + ".wav")
		write_wav(p, y, zlib.crc32(name.encode()))
		print("wrote", os.path.relpath(p), "%.2f s" % (len(y) / SR))


if __name__ == "__main__":
	main()
