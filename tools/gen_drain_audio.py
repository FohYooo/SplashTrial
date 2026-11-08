#!/usr/bin/env python3
"""SPLASH TRIAL - "PULL THE PLUG" lake-drain cutscene SFX (docs/DESIGN2.md section 8).

Writes audio/sfx/dr_*.wav (16-bit PCM, 44.1 kHz, mono) for scripts/screens/drain_screen.gd:
  dr_rumble   deep cavern rumble (the lake starts to move)       dr_whirl    whirlpool gurgle + swirling bubbles
  dr_roar     roaring rush of draining water                      dr_chain    giant chain clanks and rattles
  dr_yank     the chain whips down + heavy mechanical clunk       dr_glug     the huge "GLUG!" (two gulps)
  dr_burst    the plug bursts out of the water (splash column)    dr_steam    steam hiss from the smokestacks
  dr_horn     sour, eerie steam whistle of the old paddle-steamer dr_lantern  soft warm "tink" (a lantern lights)
  dr_thud     the hull settles into the mud                       dr_creak    wooden paddle wheel creak
  dr_drip     cave water drip

Pure standard library (math/random/struct/wave), fully synthesized and deterministic (fixed seeds).
Same loudness conventions as tools/gen_audio.py (impacts louder, ambiences quieter, peaks below -1 dBFS).

    python3 tools/gen_drain_audio.py              # render everything
    python3 tools/gen_drain_audio.py dr_glug      # render only these ids
"""
import math
import os
import random
import struct
import sys
import wave
import zlib

SR = 44100
TAU = math.tau
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SFX_DIR = os.path.join(ROOT, "audio", "sfx")


# ------------------------------------------------------------------ DSP helpers (lists of floats)
def R(name):
	return random.Random(zlib.crc32(("dr/" + name).encode()))


def n_of(sec):
	return int(round(sec * SR))


def zeros(n):
	return [0.0] * n


def noise(n, rng):
	u = rng.uniform
	return [u(-1.0, 1.0) for _ in range(n)]


def lp1(x, fc):
	a = math.exp(-TAU * fc / SR)
	b = 1.0 - a
	y = 0.0
	out = [0.0] * len(x)
	for i, v in enumerate(x):
		y = b * v + a * y
		out[i] = y
	return out


def hp1(x, fc):
	lo = lp1(x, fc)
	return [a - b for a, b in zip(x, lo)]


def biquad(x, kind, fc, q=0.707, fc_fn=None, chunk=64):
	"""RBJ biquad; fc_fn(t_sec) -> fc for a sweeping filter (coefficients updated every `chunk` samples)."""
	out = [0.0] * len(x)
	x1 = x2 = y1 = y2 = 0.0
	b0 = b1 = b2 = a1 = a2 = 0.0
	for i, v in enumerate(x):
		if i % chunk == 0:
			f = fc_fn(i / SR) if fc_fn else fc
			f = min(max(f, 10.0), SR * 0.45)
			w = TAU * f / SR
			al = math.sin(w) / (2.0 * q)
			cw = math.cos(w)
			if kind == "lp":
				nb0, nb1, nb2 = (1 - cw) / 2, 1 - cw, (1 - cw) / 2
			elif kind == "hp":
				nb0, nb1, nb2 = (1 + cw) / 2, -(1 + cw), (1 + cw) / 2
			else:  # band-pass (constant peak gain)
				nb0, nb1, nb2 = al, 0.0, -al
			a0 = 1 + al
			b0, b1, b2 = nb0 / a0, nb1 / a0, nb2 / a0
			a1, a2 = -2 * cw / a0, (1 - al) / a0
		y = b0 * v + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2
		x2, x1 = x1, v
		y2, y1 = y1, y
		out[i] = y
	return out


def osc(freq_fn, n, wave_kind="sin", ph=0.0):
	"""Oscillator with a per-sample frequency function freq_fn(t_sec)."""
	out = [0.0] * n
	for i in range(n):
		f = freq_fn(i / SR)
		ph += f / SR
		p = ph - math.floor(ph)
		if wave_kind == "sin":
			out[i] = math.sin(TAU * p)
		elif wave_kind == "tri":
			out[i] = 4.0 * abs(p - 0.5) - 1.0
		else:  # soft saw
			out[i] = 2.0 * p - 1.0
	return out


def env(n, fn):
	return [fn(i / SR) for i in range(n)]


def mul(a, b):
	return [x * y for x, y in zip(a, b)]


def add_into(dst, src, t0=0.0, gain=1.0):
	o = n_of(t0)
	for i, v in enumerate(src):
		j = o + i
		if 0 <= j < len(dst):
			dst[j] += v * gain


def scale(x, g):
	return [v * g for v in x]


def tanh_sat(x, drive=1.0):
	return [math.tanh(v * drive) for v in x]


def adsr_exp(t, a, d):
	if t < 0:
		return 0.0
	if t < a:
		return t / a
	return math.exp(-(t - a) / d)


def reverb(x, t60=1.6, mix=0.3, bright=0.6, tail=1.2):
	"""Small Schroeder cave reverb: 4 damped combs + 2 allpasses."""
	n = len(x) + n_of(tail)
	src = x + [0.0] * (n - len(x))
	wet = [0.0] * n
	for dl in (1557, 1617, 1491, 1422):
		g = 10 ** (-3.0 * dl / SR / t60)
		buf = [0.0] * dl
		k = 0
		lpz = 0.0
		damp = 1.0 - bright * 0.5
		for i in range(n):
			yv = buf[k]
			lpz = yv * (1 - damp * 0.5) + lpz * damp * 0.5
			buf[k] = src[i] + lpz * g
			wet[i] += yv
			k += 1
			if k >= dl:
				k = 0
	for dl, g in ((225, 0.6), (556, 0.55)):
		buf = [0.0] * dl
		k = 0
		out = [0.0] * n
		for i in range(n):
			bv = buf[k]
			v = wet[i] + bv * g
			out[i] = bv - v * g
			buf[k] = v
			k += 1
			if k >= dl:
				k = 0
		wet = out
	return [s + w * mix * 0.25 for s, w in zip(src, wet)]


def finish(x, peak_db=-1.5, rms_db=None, fade_ms=8.0):
	"""DC-block, trim trailing silence, fade, loudness (RMS) + peak normalize with a soft clip."""
	x = hp1(x, 20.0)
	pk = max(1e-9, max(abs(v) for v in x))
	thr = pk * 10 ** (-60 / 20)
	end = len(x)
	while end > 1 and abs(x[end - 1]) < thr:
		end -= 1
	x = x[:min(len(x), end + n_of(0.02))]
	fi = n_of(0.0008)
	for i in range(min(fi, len(x))):
		x[i] *= i / fi
	fo = n_of(fade_ms / 1000.0)
	for i in range(min(fo, len(x))):
		x[len(x) - 1 - i] *= i / fo
	if rms_db is not None:
		r = math.sqrt(sum(v * v for v in x) / max(1, len(x)))
		x = scale(x, 10 ** (rms_db / 20) / max(r, 1e-9))
	ceil = 10 ** (peak_db / 20)
	pk = max(abs(v) for v in x)
	if pk > ceil:
		# soft-limit the loud parts only
		x = [ceil * math.tanh(v / ceil) if abs(v) > ceil * 0.6 else v for v in x]
		pk = max(abs(v) for v in x)
		if pk > ceil:
			x = scale(x, ceil / pk)
	return x


def write(name, x):
	os.makedirs(SFX_DIR, exist_ok=True)
	path = os.path.join(SFX_DIR, name + ".wav")
	rng = R("dither/" + name)
	frames = bytearray()
	for v in x:
		d = (rng.random() - rng.random()) / 32768.0
		q = int(round((v + d) * 32767.0))
		frames += struct.pack("<h", max(-32768, min(32767, q)))
	with wave.open(path, "wb") as w:
		w.setnchannels(1)
		w.setsampwidth(2)
		w.setframerate(SR)
		w.writeframes(bytes(frames))
	pk = max(abs(v) for v in x) if x else 0.0
	r = math.sqrt(sum(v * v for v in x) / max(1, len(x)))
	print("%-11s %5.2f s  peak %6.1f dB  rms %6.1f dB  %5.0f KB" % (
		name, len(x) / SR, 20 * math.log10(max(pk, 1e-9)), 20 * math.log10(max(r, 1e-9)), os.path.getsize(path) / 1024.0))


# ------------------------------------------------------------------ the sounds
def bubble(f0, dur, rise=2.2):
	"""One water bubble 'bloop' (sine chirping up)."""
	n = n_of(dur)
	return [math.sin(TAU * f0 * (t + rise * t * t * 0.5 / max(dur, 1e-3))) * math.exp(-t / (dur * 0.35)) * min(1.0, t / 0.002)
		for t in (i / SR for i in range(n))]


def dr_rumble():
	rng = R("rumble")
	dur = 6.0
	n = n_of(dur)
	br = lp1(lp1(noise(n, rng), 90.0), 70.0)
	sub = osc(lambda t: 34.0 + 6.0 * math.sin(TAU * 0.7 * t) + 3.0 * math.sin(TAU * 1.9 * t), n)
	grit = biquad(noise(n, rng), "bp", 180.0, 1.2, fc_fn=lambda t: 140 + 90 * math.sin(TAU * 0.33 * t))
	shape = env(n, lambda t: min(1.0, t / 1.2) * (1.0 - max(0.0, (t - 4.6) / 1.4)) * (0.8 + 0.2 * math.sin(TAU * 0.9 * t)))
	y = [(9.0 * a + 0.55 * b + 0.22 * c) * s for a, b, c, s in zip(br, sub, grit, shape)]
	y = tanh_sat(y, 1.4)
	return finish(reverb(y, 2.4, 0.35, 0.3, 1.5), rms_db=-19.0)


def dr_whirl():
	rng = R("whirl")
	dur = 7.0
	n = n_of(dur)
	nz = noise(n, rng)
	swirl = biquad(nz, "bp", 600, 2.2, fc_fn=lambda t: 520 + 360 * math.sin(TAU * (0.6 + t * 0.12) * t))
	swirl2 = biquad(nz, "bp", 1500, 3.0, fc_fn=lambda t: 1300 + 700 * math.sin(TAU * 1.1 * t + 1.0))
	low = lp1(lp1(noise(n, rng), 140.0), 120.0)
	shape = env(n, lambda t: min(1.0, t / 0.8) * (1.0 - max(0.0, (t - 5.6) / 1.4)))
	y = [(0.9 * a + 0.35 * b + 5.0 * c) * s for a, b, c, s in zip(swirl, swirl2, low, shape)]
	t = 0.1
	while t < dur - 0.4:
		f0 = rng.uniform(260, 900)
		add_into(y, bubble(f0, rng.uniform(0.04, 0.11), rng.uniform(1.5, 3.5)), t, rng.uniform(0.15, 0.45) * min(1.0, t / 1.0))
		t += rng.uniform(0.02, 0.14)
	return finish(reverb(y, 1.8, 0.3, 0.5, 1.0), rms_db=-21.0)


def dr_roar():
	rng = R("roar")
	dur = 6.5
	n = n_of(dur)
	nz = noise(n, rng)
	body = lp1(lp1(nz, 1800.0), 2400.0)
	hiss = hp1(lp1(noise(n, rng), 6000.0), 2500.0)
	low = lp1(lp1(noise(n, rng), 120.0), 100.0)
	shape = env(n, lambda t: min(1.0, (t / 1.6) ** 1.5) * (1.0 - max(0.0, (t - 5.0) / 1.5)) * (0.85 + 0.15 * math.sin(TAU * 0.5 * t)))
	y = [(1.0 * a + 0.25 * b + 6.0 * c) * s for a, b, c, s in zip(body, hiss, low, shape)]
	return finish(reverb(tanh_sat(y, 1.2), 2.2, 0.4, 0.4, 1.5), rms_db=-19.0)


def metal_hit(rng, dur=0.5, base=1.0):
	n = n_of(dur)
	parts = [(1180 * base, 0.5, 0.28), (2230 * base, 0.35, 0.18), (3470 * base, 0.25, 0.12), (4690 * base, 0.15, 0.08), (620 * base, 0.4, 0.2)]
	ph = [rng.random() for _ in parts]
	out = [0.0] * n
	for i in range(n):
		t = i / SR
		v = 0.0
		for (f, a, d), p in zip(parts, ph):
			v += a * math.sin(TAU * (f * t + p)) * math.exp(-t / d)
		out[i] = v
	click = hp1(noise(n_of(0.01), rng), 2500.0)
	for i, c in enumerate(click):
		out[i] += c * 0.8 * (1 - i / len(click))
	return out


def dr_chain():
	rng = R("chain")
	dur = 1.8
	y = zeros(n_of(dur))
	t = 0.0
	k = 0
	while t < 1.25:
		g = rng.uniform(0.35, 1.0) * (1.0 - t / 1.6)
		add_into(y, metal_hit(rng, 0.35, rng.uniform(0.75, 1.3)), t, g)
		t += rng.uniform(0.03, 0.11) if k % 4 else rng.uniform(0.12, 0.2)
		k += 1
	# a strained creak underneath
	n = n_of(1.4)
	src = [0.0] * n
	ph = 0.0
	for i in range(n):
		ph += (26 + 14 * math.sin(TAU * 1.3 * i / SR)) / SR
		if ph >= 1.0:
			ph -= 1.0
			src[i] = rng.uniform(0.5, 1.0)
	cr = biquad(src, "bp", 420, 6) + []
	cr2 = biquad(src, "bp", 980, 8)
	add_into(y, [(a + 0.7 * b) * 0.9 for a, b in zip(cr, cr2)], 0.05, 1.0)
	return finish(reverb(y, 1.4, 0.3, 0.6, 0.8), rms_db=-20.0)


def dr_yank():
	rng = R("yank")
	dur = 1.1
	n = n_of(dur)
	# the zip: chain beads whipping through a guide (rapid ticks rising in rate)
	y = zeros(n)
	t = 0.0
	while t < 0.26:
		add_into(y, metal_hit(rng, 0.08, rng.uniform(1.2, 1.8)), t, 0.35)
		t += 0.012 + 0.03 * (1 - t / 0.26)
	# the clunk
	m = n_of(0.9)
	thump = [math.sin(TAU * (55 * tt + 40 * 0.05 * (1 - math.exp(-tt / 0.05)))) * math.exp(-tt / 0.22) * min(1.0, tt / 0.002)
		for tt in (i / SR for i in range(m))]
	knock = biquad(noise(m, rng), "bp", 240, 3)
	knock = [v * math.exp(-(i / SR) / 0.05) * 4.0 for i, v in enumerate(knock)]
	add_into(y, [a + b for a, b in zip(thump, knock)], 0.26, 1.2)
	add_into(y, metal_hit(rng, 0.5, 0.8), 0.27, 0.7)
	return finish(reverb(tanh_sat(y, 1.5), 1.6, 0.35, 0.5, 0.8), rms_db=-17.0)


def gulp(f0, f1, dur, rng):
	n = n_of(dur)
	ph = 0.0
	out = [0.0] * n
	for i in range(n):
		t = i / SR
		k = t / dur
		f = f0 * (f1 / f0) ** k
		ph += f / SR
		e = math.sin(math.pi * min(1.0, k * 1.1)) ** 0.6
		out[i] = (math.sin(TAU * ph) + 0.4 * math.sin(TAU * 2 * ph + 0.5)) * e
	formant = biquad(out, "bp", 420, 1.4)
	return [a * 0.6 + b * 1.4 for a, b in zip(out, formant)]


def dr_glug():
	rng = R("glug")
	dur = 2.2
	y = zeros(n_of(dur))
	add_into(y, gulp(210, 70, 0.42, rng), 0.0, 1.0)
	add_into(y, gulp(170, 52, 0.58, rng), 0.48, 1.1)
	# sloshing water tail
	n = n_of(1.4)
	sl = biquad(noise(n, rng), "bp", 700, 1.5, fc_fn=lambda t: 900 - 500 * t)
	sl = [v * math.exp(-t / 0.5) * min(1.0, t / 0.08) for v, t in zip(sl, (i / SR for i in range(n)))]
	add_into(y, sl, 0.55, 0.5)
	t = 0.05
	while t < 1.4:
		add_into(y, bubble(rng.uniform(180, 520), rng.uniform(0.05, 0.12), 2.0), t, rng.uniform(0.15, 0.35))
		t += rng.uniform(0.04, 0.16)
	sub = [math.sin(TAU * 42 * tt) * math.exp(-tt / 0.35) for tt in (i / SR for i in range(n_of(1.0)))]
	add_into(y, sub, 0.48, 0.6)
	return finish(reverb(tanh_sat(y, 1.3), 2.0, 0.45, 0.4, 1.2), rms_db=-16.0)


def dr_burst():
	rng = R("burst")
	dur = 1.6
	n = n_of(dur)
	nz = noise(n, rng)
	crash = biquad(nz, "lp", 3000, 0.7, fc_fn=lambda t: 5000 * math.exp(-t / 0.4) + 600)
	crash = [v * adsr_exp(i / SR, 0.004, 0.25) for i, v in enumerate(crash)]
	spray = hp1(noise(n, rng), 3000.0)
	spray = [v * adsr_exp(i / SR, 0.05, 0.5) * 0.4 for i, v in enumerate(spray)]
	thump = [math.sin(TAU * (48 * t + 30 * 0.04 * (1 - math.exp(-t / 0.04)))) * math.exp(-t / 0.25) for t in (i / SR for i in range(n))]
	y = [a * 1.4 + b + c * 1.2 for a, b, c in zip(crash, spray, thump)]
	t = 0.15
	while t < 1.2:
		add_into(y, bubble(rng.uniform(400, 1400), rng.uniform(0.03, 0.07), 2.5), t, rng.uniform(0.1, 0.3))
		t += rng.uniform(0.03, 0.1)
	return finish(reverb(tanh_sat(y, 1.4), 1.8, 0.4, 0.6, 1.0), rms_db=-17.0)


def dr_steam():
	rng = R("steam")
	dur = 2.4
	n = n_of(dur)
	h = hp1(hp1(noise(n, rng), 2200.0), 1800.0)
	h = biquad(h, "lp", 9000, 0.7)
	shape = env(n, lambda t: min(1.0, t / 0.03) * math.exp(-t / 0.9) * (0.9 + 0.1 * math.sin(TAU * 17 * t)))
	y = mul(h, shape)
	puff = lp1(noise(n_of(0.4), rng), 400.0)
	add_into(y, [v * math.exp(-(i / SR) / 0.1) * 3.0 for i, v in enumerate(puff)], 0.0, 1.0)
	return finish(reverb(y, 1.5, 0.3, 0.7, 0.8), rms_db=-21.0)


def dr_horn():
	rng = R("horn")
	dur = 3.4
	n = n_of(dur)
	y = zeros(n)
	# a slightly sour three-chime steam whistle (minor-ish, detuned)
	for f, a in ((233.1, 1.0), (276.0, 0.85), (349.6, 0.7), (466.0, 0.25)):
		det = rng.uniform(-1.2, 1.2)
		tone = osc(lambda t, f=f, det=det: (f + det) * (1.0 + 0.004 * math.sin(TAU * 5.2 * t)) * (0.985 + 0.015 * min(1.0, t / 0.25)), n, "tri")
		add_into(y, tone, 0.0, a)
	breath = biquad(noise(n, rng), "bp", 1400, 1.0)
	y = [v + b * 0.6 for v, b in zip(y, breath)]
	y = biquad(y, "lp", 2600, 0.8)
	shape = env(n, lambda t: min(1.0, (t / 0.18)) * (1.0 if t < 2.2 else max(0.0, 1.0 - (t - 2.2) / 0.9)) * (0.9 + 0.1 * math.sin(TAU * 3 * t)))
	y = mul(y, shape)
	return finish(reverb(y, 2.8, 0.55, 0.4, 2.0), rms_db=-18.0)


def dr_lantern():
	rng = R("lantern")
	dur = 0.6
	n = n_of(dur)
	ping = [(math.sin(TAU * 1760 * t) + 0.4 * math.sin(TAU * 4410 * t + 0.3)) * math.exp(-t / 0.12) * min(1.0, t / 0.001) for t in (i / SR for i in range(n))]
	whoomp = lp1(noise(n, rng), 500.0)
	whoomp = [v * math.sin(math.pi * min(1.0, (i / SR) / 0.18)) * 3.0 * (1 if i / SR < 0.18 else 0) for i, v in enumerate(whoomp)]
	y = [a * 0.6 + b for a, b in zip(ping, whoomp)]
	return finish(reverb(y, 1.2, 0.35, 0.8, 0.6), rms_db=-23.0)


def dr_thud():
	rng = R("thud")
	dur = 1.6
	n = n_of(dur)
	sub = [math.sin(TAU * (38 * t + 70 * 0.05 * (1 - math.exp(-t / 0.05)))) * math.exp(-t / 0.4) * min(1.0, t / 0.003) for t in (i / SR for i in range(n))]
	squelch = biquad(noise(n, rng), "bp", 500, 2.0, fc_fn=lambda t: 300 + 900 * t)
	squelch = [v * adsr_exp(i / SR, 0.05, 0.25) * 1.5 for i, v in enumerate(squelch)]
	wood = biquad(noise(n, rng), "bp", 160, 4)
	wood = [v * math.exp(-(i / SR) / 0.08) * 5 for i, v in enumerate(wood)]
	y = [a * 1.3 + b + c for a, b, c in zip(sub, squelch, wood)]
	t = 0.2
	while t < 1.1:
		add_into(y, bubble(rng.uniform(150, 400), rng.uniform(0.05, 0.1), 1.6), t, rng.uniform(0.1, 0.25))
		t += rng.uniform(0.06, 0.2)
	return finish(reverb(tanh_sat(y, 1.5), 2.0, 0.4, 0.4, 1.0), rms_db=-17.0)


def dr_creak():
	rng = R("creak")
	dur = 2.0
	n = n_of(dur)
	src = [0.0] * n
	ph = 0.0
	for i in range(n):
		t = i / SR
		rate = 40 + 60 * (0.5 + 0.5 * math.sin(TAU * 0.9 * t + 0.4))
		ph += rate / SR
		if ph >= 1.0:
			ph -= 1.0
			src[i] = rng.uniform(0.4, 1.0)
	y = [a + 0.75 * b + 0.4 * c for a, b, c in zip(biquad(src, "bp", 380, 7), biquad(src, "bp", 860, 9), biquad(src, "bp", 1650, 10))]
	shape = env(n, lambda t: math.sin(math.pi * min(1.0, t / dur)) ** 0.7)
	return finish(reverb(mul(y, shape), 1.5, 0.35, 0.5, 0.8), rms_db=-21.0)


def dr_drip():
	rng = R("drip")
	dur = 0.5
	n = n_of(dur)
	ph = 0.0
	y = [0.0] * n
	for i in range(n):
		t = i / SR
		f = 1100 * (1 + 1.6 * min(1.0, t / 0.03))
		ph += f / SR
		y[i] = math.sin(TAU * ph) * math.exp(-t / 0.035) * min(1.0, t / 0.001)
	return finish(reverb(y, 2.4, 0.6, 0.6, 1.4), rms_db=-25.0)


SOUNDS = ["dr_rumble", "dr_whirl", "dr_roar", "dr_chain", "dr_yank", "dr_glug", "dr_burst", "dr_steam", "dr_horn",
	"dr_lantern", "dr_thud", "dr_creak", "dr_drip"]


def main():
	only = set(sys.argv[1:])
	g = globals()
	for name in SOUNDS:
		if only and name not in only:
			continue
		write(name, g[name]())


if __name__ == "__main__":
	main()
