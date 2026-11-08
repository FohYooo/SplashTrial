#!/usr/bin/env python3
"""
SPLASH TRIAL - Chapter 2 execution audio ("THE ENDLESS LULLABY"). Python standard library only.

Renders 16-bit PCM, 32 kHz, mono WAV files (same format and loudness targets as the other generators):

    audio/music/execution_lullaby.wav   52 s seamless loop. A detuned music-box lullaby (original melody, A minor,
                                        3/4) on a warbling tape over beating low drones. Music time m = screen time - 4:
                                          m  0-18  lullaby, slightly out of tune; ghost hum from m 12
                                          m 18-24  the tape drags: slower and flatter; m 24-28 the box falls silent
                                          m 28-37  re-wound: the lullaby speeds up and warps, pitch rising, ticking,
                                                   a sour second box, a whining cluster (the screen stops here)
                                          m 37-52  winds back down to the opening tempo so the file loops
    audio/sfx/lx_*.wav                  windup, ratchet, creak, chain, thud, splash, winddown, laugh, wheel, drip,
                                        lapping, turn, sputter

Everything is synthesized (no samples, no real voices) and deterministic (fixed seeds).

    python3 tools/gen_exec2_audio.py              # render everything + print a level table
    python3 tools/gen_exec2_audio.py lx_thud      # render only these ids
"""
import array
import math
import os
import random
import sys
import time
import wave
import zlib

SR = 32000
TAU = 2.0 * math.pi
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MUSIC_DIR = os.path.join(ROOT, "audio", "music")
SFX_DIR = os.path.join(ROOT, "audio", "sfx")
CEIL = 10 ** (-1.0 / 20.0)        # -1 dBFS true-peak-ish ceiling
MUSIC_RMS_DB = -18.0


# =====================================================================================  DSP core (lists of floats)
def R(name):
	return random.Random(zlib.crc32(("lx/" + name).encode()))


def nlen(sec, sr=SR):
	return int(round(sec * sr))


def zeros(n):
	return [0.0] * n


def undb(d):
	return 10.0 ** (d / 20.0)


def db(x):
	return 20.0 * math.log10(max(x, 1e-12))


def midi_hz(m):
	return 440.0 * 2.0 ** ((m - 69.0) / 12.0)


def add_into(dst, src, start, gain=1.0, wrap=False):
	"""dst[start:] += gain * src (circularly when wrap, else clipped at the end)."""
	n = len(dst)
	m = len(src)
	if wrap:
		s = start % n
		pos = 0
		while pos < m:
			k = min(n - s, m - pos)
			seg = src[pos:pos + k]
			dst[s:s + k] = [a + gain * b for a, b in zip(dst[s:s + k], seg)]
			pos += k
			s = 0
		return
	if start >= n:
		return
	if start < 0:
		src = src[-start:]
		start = 0
	k = min(n - start, len(src))
	dst[start:start + k] = [a + gain * b for a, b in zip(dst[start:start + k], src[:k])]


def mix(*parts):
	"""Sum (gain, list) pairs of equal length."""
	n = len(parts[0][1])
	out = zeros(n)
	for g, x in parts:
		out = [a + g * b for a, b in zip(out, x)]
	return out


def scale(x, g):
	return [v * g for v in x]


def lp1(x, fc, sr=SR, state=0.0):
	a = math.exp(-TAU * fc / sr)
	b = 1.0 - a
	y = state
	out = [0.0] * len(x)
	for i, v in enumerate(x):
		y = b * v + a * y
		out[i] = y
	return out


def hp1(x, fc, sr=SR):
	lo = lp1(x, fc, sr)
	return [a - b for a, b in zip(x, lo)]


def bq_coef(kind, fc, q, sr=SR):
	w = TAU * min(fc, sr * 0.45) / sr
	c, s = math.cos(w), math.sin(w)
	al = s / (2.0 * q)
	if kind == "lp":
		b = ((1 - c) / 2, 1 - c, (1 - c) / 2)
	elif kind == "hp":
		b = ((1 + c) / 2, -(1 + c), (1 + c) / 2)
	else:  # band-pass, 0 dB peak
		b = (al, 0.0, -al)
	a0 = 1 + al
	return (b[0] / a0, b[1] / a0, b[2] / a0, -2 * c / a0, (1 - al) / a0)


def bq(x, kind, fc, q=0.707, sr=SR):
	b0, b1, b2, a1, a2 = bq_coef(kind, fc, q, sr)
	x1 = x2 = y1 = y2 = 0.0
	out = [0.0] * len(x)
	for i, v in enumerate(x):
		y = b0 * v + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2
		x2, x1 = x1, v
		y2, y1 = y1, y
		out[i] = y
	return out


def resonators(x, bank, sr=SR):
	"""Sum of band-pass biquads [(fc, gain, q), ...] over the same input."""
	out = zeros(len(x))
	for fc, g, q in bank:
		y = bq(x, "bp", fc, q, sr)
		out = [a + g * b for a, b in zip(out, y)]
	return out


def noise(n, rng):
	r = rng.random
	return [r() * 2.0 - 1.0 for _ in range(n)]


def env_ad(n, a, d, sr=SR):
	"""Linear attack a seconds, exponential decay time constant d seconds."""
	out = [0.0] * n
	na = max(1, int(a * sr))
	k = math.exp(-1.0 / (d * sr))
	g = 1.0
	for i in range(n):
		if i < na:
			out[i] = i / na
		else:
			out[i] = g
			g *= k
	return out


def mul(x, y):
	return [a * b for a, b in zip(x, y)]


def damped(f, amp, dec, n, sr=SR, ph=0.0):
	"""amp * exp(-t/dec) * sin(2 pi f t + ph) via a resonator recursion."""
	w = TAU * f / sr
	g = math.exp(-1.0 / (dec * sr))
	a1 = 2.0 * g * math.cos(w)
	a2 = g * g
	out = [0.0] * n
	y0 = amp * math.sin(ph - w) / g
	y1 = amp * math.sin(ph)
	for i in range(n):
		out[i] = y1
		y0, y1 = y1, a1 * y1 - a2 * y0
	return out


def sine(f, n, sr=SR, ph=0.0, amp=1.0):
	return damped(f, amp, 1e9, n, sr, ph)


def sweep(f_of_t, n, sr=SR, amp=1.0):
	"""Sine with a per-sample frequency function f(t)."""
	out = [0.0] * n
	ph = 0.0
	for i in range(n):
		ph += TAU * f_of_t(i / sr) / sr
		out[i] = amp * math.sin(ph)
	return out


def fade_in(x, ms=1.0, sr=SR):
	k = max(1, int(ms * sr / 1000.0))
	for i in range(min(k, len(x))):
		x[i] *= i / k
	return x


def fade_out(x, ms=5.0, sr=SR):
	k = max(1, int(ms * sr / 1000.0))
	n = len(x)
	for i in range(min(k, n)):
		x[n - 1 - i] *= i / k
	return x


def softclip(v, knee=0.5):
	a = abs(v)
	if a <= knee:
		return v
	head = CEIL - knee
	y = knee + head * math.tanh((a - knee) / head)
	return y if v > 0 else -y


def reverb(x, t60=2.0, wet=0.3, size=1.0, damp=0.35, sr=SR, seed=1, circular=False, predelay=0.012):
	"""Schroeder/Freeverb-style mono reverb (4 damped combs + 2 allpasses). circular=True runs it twice
	over the buffer so the loop seam sees the steady-state tail."""
	rng = random.Random(seed)
	base = [0.0297, 0.0371, 0.0411, 0.0437]
	combs = [max(8, int(sr * d * size * (1 + rng.uniform(-0.03, 0.03)))) for d in base]
	aps = [(max(4, int(sr * 0.005 * size)), 0.7), (max(4, int(sr * 0.0017 * size)), 0.7)]
	n = len(x)
	pd = int(predelay * sr)
	passes = 2 if circular else 1
	bufs = [[0.0] * d for d in combs]
	idx = [0] * 4
	lpst = [0.0] * 4
	fbs = [10 ** (-3.0 * d / (t60 * sr)) for d in combs]
	apb = [[0.0] * d for d, _ in aps]
	api = [0, 0]
	out = [0.0] * n
	total = n if not circular else 2 * n
	for j in range(total):
		i = j % n
		src = j - pd
		v = x[src % n] if (circular or src >= 0) else 0.0
		acc = 0.0
		for c in range(4):
			buf = bufs[c]
			k = idx[c]
			yv = buf[k]
			lpst[c] = yv * (1 - damp) + lpst[c] * damp
			buf[k] = v + lpst[c] * fbs[c]
			idx[c] = k + 1 if k + 1 < combs[c] else 0
			acc += yv
		acc *= 0.25
		for a in range(2):
			buf = apb[a]
			k = api[a]
			g = aps[a][1]
			bv = buf[k]
			yv = -acc * g + bv
			buf[k] = acc + bv * g
			api[a] = k + 1 if k + 1 < aps[a][0] else 0
			acc = yv
		if j >= total - n:
			out[i] = acc
	return [a + wet * b for a, b in zip(x, out)] if wet is not None else out


def resample_up(x, factor, n_out):
	"""Linear-interpolating integer upsampler (circular)."""
	m = len(x)
	out = [0.0] * n_out
	for i in range(n_out):
		p = i / factor
		k = int(p)
		fr = p - k
		out[i] = x[k % m] * (1 - fr) + x[(k + 1) % m] * fr
	return out


def kweight(x):
	y = bq(x, "hp", 38.0, 0.5)
	h = hp1(y, 1700.0)
	return [a + 0.58 * b for a, b in zip(y, h)]


def st_loud(x, win=0.1):
	"""Max short-term (100 ms) K-weighted-ish RMS in dB (same measure as tools/gen_audio.py)."""
	y = kweight(x)
	w = nlen(win)
	c = [0.0]
	s = 0.0
	for v in y:
		s += v * v
		c.append(s)
	if len(y) <= w:
		return 10 * math.log10(c[-1] / w + 1e-20)
	best = max(c[i + w] - c[i] for i in range(len(y) - w))
	return 10 * math.log10(best / w + 1e-20)


def finish_sfx(x, loud=-14.0):
	x = hp1(x, 18.0)
	pk = max(abs(v) for v in x) or 1.0
	thr = pk * undb(-62)
	end = len(x)
	while end > 1 and abs(x[end - 1]) < thr:
		end -= 1
	x = x[:min(len(x), end + nlen(0.01))]
	x = fade_out(fade_in(x, 0.4), 6)
	g = undb(loud - st_loud(x))
	x = [v * g for v in x]
	if max(abs(v) for v in x) > CEIL:
		x = [softclip(v, 0.6) for v in x]
	return x


def rms(x):
	return math.sqrt(sum(v * v for v in x) / max(1, len(x)))


def write_wav(path, y, seed=0):
	rng = random.Random(seed)
	r = rng.random
	q = array.array("h", [max(-32768, min(32767, int(round((v + (r() - r()) / 32768.0) * 32767.0)))) for v in y])
	if sys.byteorder == "big":
		q.byteswap()
	os.makedirs(os.path.dirname(path), exist_ok=True)
	with wave.open(path, "wb") as w:
		w.setnchannels(1)
		w.setsampwidth(2)
		w.setframerate(SR)
		w.writeframes(q.tobytes())


# =====================================================================================  instruments
_MB_CACHE = {}


def mbox(f, vel=1.0, bright=1.0, dur=None):
	"""Music-box tine: fundamental + slightly stretched octave + the tine's bright 5.4x partial + a pluck click.
	Cached per (frequency in 5-cent steps, bright, dur)."""
	cents = int(round(1200.0 * math.log2(f / 440.0) / 5.0)) * 5
	key = (cents, round(bright, 2), dur)
	if key not in _MB_CACHE:
		fq = 440.0 * 2.0 ** (cents / 1200.0)
		d = min(2.2, max(0.45, 1.25 * (523.0 / fq) ** 0.5))
		n = nlen(dur if dur else min(3.2, d * 3.2))
		y = damped(fq, 1.0, d, n)
		if fq * 2 < 14000:
			y = [a + b for a, b in zip(y, damped(fq * 2.004, 0.12, d * 0.45, n))]
		if fq * 5.4 < 14000:
			y = [a + b for a, b in zip(y, damped(fq * 5.4, 0.22 * bright, d * 0.07, n))]
		rng = random.Random(cents)
		cl = nlen(0.004)
		for i in range(cl):
			y[i] += (rng.random() * 2 - 1) * 0.3 * bright * (1 - i / cl)
		_MB_CACHE[key] = fade_out(y, 8)
	y = _MB_CACHE[key]
	return y if vel == 1.0 else [v * vel for v in y]


def click_tpl(rng, fc=3200.0, dec=0.003, ring=0.02, amp=1.0, n_sec=0.06):
	n = nlen(n_sec)
	nz = noise(n, rng)
	e = env_ad(n, 0.0002, dec)
	y = bq(mul(nz, e), "bp", fc, 2.5)
	pr = damped(fc * 1.13, 0.5, ring, n)
	return [amp * (a * 2.2 + b) for a, b in zip(y, pr)]


def stick_slip(n, rng, rate_lo, rate_hi, wob=1.0):
	"""Impulse train of a creaking hinge: irregular rate, random heights."""
	x = [0.0] * n
	ph = 0.0
	slow = 0.0
	for i in range(n):
		t = i / SR
		slow += (rng.random() - 0.5) * 0.02
		slow *= 0.999
		rate = rate_lo + (rate_hi - rate_lo) * (0.5 + 0.5 * math.sin(TAU * wob * t)) * (0.8 + 0.2 * max(-1, min(1, slow * 20)))
		ph += rate / SR
		if ph >= 1.0:
			ph -= 1.0
			x[i] = rng.uniform(0.4, 1.0) * (1.8 if rng.random() < 0.15 else 1.0)
	return x


def wood(x, low=1.0):
	return resonators(x, [(230 * low, 0.35, 4), (420 * low, 1.0, 6), (980 * low, 0.7, 8), (1750 * low, 0.4, 10), (2900 * low, 0.2, 12)])


def formant(src, vowel, shift=1.0):
	F = {"a": ((750, 1.0, 9), (1200, 0.7, 10), (2550, 0.35, 12)),
		"o": ((480, 1.0, 9), (860, 0.6, 10), (2400, 0.2, 12)),
		"e": ((420, 1.0, 9), (2000, 0.55, 12), (2700, 0.3, 12)),
		"u": ((330, 1.0, 9), (760, 0.4, 10), (2300, 0.15, 12))}[vowel]
	return resonators(src, [(fc * shift, g, q) for fc, g, q in F])


# =====================================================================================  SFX
def lx_windup():
	"""A music box being wound behind the static: four strokes of ratchet clicks, tension rising."""
	rng = R("windup")
	out = zeros(nlen(2.9))
	t = 0.05
	for stroke in range(4):
		k = 7 + stroke
		for c in range(k):
			fc = 2600 + 140 * stroke + 40 * c + rng.uniform(-80, 80)
			tpl = click_tpl(rng, fc, 0.0025, 0.018, rng.uniform(0.6, 1.0))
			add_into(out, tpl, nlen(t))
			t += rng.uniform(0.026, 0.036)
		# the spring settling: a soft metallic groan
		n = nlen(0.22)
		g = sweep(lambda tt, s=stroke: 610 + 40 * s + 160 * tt, n, amp=0.05)
		g = mul(g, env_ad(n, 0.03, 0.08))
		add_into(out, g, nlen(t))
		t += rng.uniform(0.22, 0.3)
	y = reverb(out, 1.1, 0.28, 0.6, seed=3)
	return finish_sfx(lp1(y, 9000), -16)


def lx_ratchet():
	"""One big crank of the giant key: four heavy pawl clacks and a clunk."""
	rng = R("ratchet")
	out = zeros(nlen(1.0))
	for c in range(4):
		tpl = click_tpl(rng, 1400 + c * 60, 0.006, 0.05, 1.0, 0.14)
		low = mul(damped(180 + c * 6, 0.6, 0.04, nlen(0.14)), env_ad(nlen(0.14), 0.0005, 0.03))
		add_into(out, [a + b for a, b in zip(tpl, low)], nlen(0.02 + c * 0.05))
	n = nlen(0.5)
	cl = wood(mul(noise(n, rng), env_ad(n, 0.0005, 0.004)), 0.5)
	cl = [a + b for a, b in zip(cl, damped(95, 0.8, 0.08, n))]
	add_into(out, cl, nlen(0.22), 1.2)
	y = reverb(out, 1.4, 0.3, 0.8, seed=5)
	return finish_sfx(y, -14)


def lx_creak():
	"""The cradle swinging: a stretched wooden creak with the chain ring grinding."""
	rng = R("creak")
	dur = 1.3
	n = nlen(dur)
	x = stick_slip(n, rng, 35, 120, 0.8)
	body = wood(x)
	ring = resonators(stick_slip(n, rng, 60, 180, 1.3), [(2150, 0.5, 18), (3420, 0.3, 22)])
	y = [0.0] * n
	for i in range(n):
		t = i / SR
		e = math.sin(math.pi * min(1.0, t / dur)) ** 0.6 * (0.7 + 0.3 * math.sin(TAU * 1.3 * t + 0.4))
		y[i] = (body[i] + 0.35 * ring[i]) * e
	y = reverb(y, 1.2, 0.3, 0.7, seed=9)
	return finish_sfx(y, -15)


def lx_chain():
	"""Chain links clinking and running over the crane pulley."""
	rng = R("chain")
	out = zeros(nlen(1.5))
	n = nlen(0.08)
	for k in range(46):
		t = rng.uniform(0, 0.9) ** 1.4
		f0 = rng.uniform(1900, 5200)
		y = [0.0] * n
		for (ratio, a, d) in ((1.0, 1.0, rng.uniform(0.01, 0.04)), (1.48, 0.5, 0.015), (2.31, 0.3, 0.008)):
			y = [p + q for p, q in zip(y, damped(f0 * ratio, a, d, n, ph=rng.random() * TAU))]
		add_into(out, y, nlen(t), rng.uniform(0.25, 0.8) * (1 - t))
	m = nlen(0.3)
	clank = wood(mul(noise(m, rng), env_ad(m, 0.0004, 0.006)), 0.6)
	add_into(out, clank, nlen(0.01), 0.8)
	return finish_sfx(reverb(out, 1.3, 0.3, 0.7, seed=4), -15)


def lx_thud():
	"""Heavy impact into the paddle wheel: sub drop, wood crack, water slap, cavern tail."""
	rng = R("thud")
	dur = 2.9
	n = nlen(dur)
	sub = sweep(lambda t: 34 + 85 * math.exp(-t / 0.05), n)
	e = env_ad(n, 0.0015, 0.42)
	sub = mul(sub, e)
	m = nlen(0.5)
	knock = wood(mul(noise(m, rng), env_ad(m, 0.0004, 0.01)), 0.42)
	crack = bq(mul(noise(nlen(0.2), rng), env_ad(nlen(0.2), 0.0003, 0.012)), "hp", 2500, 0.7)
	w = nlen(0.9)
	slap = lp1(lp1(mul(noise(w, rng), env_ad(w, 0.002, 0.09)), 1400), 1400)
	spray = bq(mul(noise(w, rng), env_ad(w, 0.03, 0.25)), "bp", 1800, 0.8)
	out = zeros(n)
	add_into(out, sub, 0, 1.2)
	add_into(out, knock, 0, 1.0)
	add_into(out, crack, 0, 0.5)
	add_into(out, slap, nlen(0.012), 1.3)
	add_into(out, spray, nlen(0.04), 0.35)
	out = [math.tanh(1.5 * v) for v in out]
	y = reverb(out, 2.6, 0.42, 1.3, damp=0.5, seed=11)
	return finish_sfx(y, -11)


def lx_splash():
	"""Something heavy goes into the black water: plunge, rain of drops, then a sinking gurgle."""
	rng = R("splash")
	dur = 3.4
	out = zeros(nlen(dur))
	m = nlen(1.0)
	plunge = lp1(mul(noise(m, rng), env_ad(m, 0.004, 0.16)), 1800)
	thump = mul(sweep(lambda t: 40 + 60 * math.exp(-t / 0.04), m), env_ad(m, 0.002, 0.15))
	add_into(out, [a * 1.4 + b for a, b in zip(plunge, thump)], 0)
	sheet = bq(mul(noise(m, rng), env_ad(m, 0.05, 0.3)), "bp", 1200, 0.6)
	add_into(out, sheet, nlen(0.05), 0.5)
	for k in range(60):
		t = 0.15 + rng.uniform(0, 1.4) ** 1.3
		d = nlen(0.05)
		f0 = rng.uniform(500, 900)
		p = sweep(lambda tt, f0=f0: f0 * (1 + 2.2 * tt / 0.05), d)
		p = mul(p, env_ad(d, 0.001, 0.012))
		add_into(out, p, nlen(t), rng.uniform(0.15, 0.4) * max(0.2, 1 - t / 1.8))
	for k in range(22):
		t = 0.9 + rng.uniform(0, 1.6)
		d = nlen(0.07)
		f0 = rng.uniform(220, 520) * (1 + 0.5 * (t - 0.9) / 1.6)
		b = mul(sweep(lambda tt, f0=f0: f0 * (1 + 1.5 * tt / 0.07), d), env_ad(d, 0.004, 0.02))
		add_into(out, b, nlen(t), rng.uniform(0.2, 0.45) * (1 - (t - 0.9) / 1.8))
	y = reverb(out, 2.4, 0.4, 1.2, damp=0.45, seed=13)
	return finish_sfx(lp1(y, 6000), -12)


def lx_winddown():
	"""The lullaby's opening on a dying music box: slower, flatter, the spring gives out."""
	out = zeros(nlen(8.0))
	notes = (76, 72, 69, 71, 68, 69, 72, 76, 74)
	t = 0.0
	gap = 0.36
	for i, m in enumerate(notes):
		cents = -6.0 * i * i
		add_into(out, mbox(midi_hz(m + cents / 100.0), 0.9 - i * 0.05), nlen(t))
		t += gap
		gap *= 1.2
	rng = R("winddown")
	n = nlen(0.12)
	add_into(out, bq(mul(noise(n, rng), env_ad(n, 0.0005, 0.006)), "bp", 1800, 1.5), nlen(t + 0.2), 0.5)
	return finish_sfx(reverb(out, 2.6, 0.45, 1.1, seed=17), -15)


def _voice(f0a, f0b, dur, rng, vowel, shift=0.72):
	n = nlen(dur + 0.06)
	src = [0.0] * n
	ph = 0.0
	for i in range(n):
		t = i / SR
		f0 = (f0a + (f0b - f0a) * min(1.0, t / dur)) * (1 + 0.015 * math.sin(TAU * 6.5 * t))
		ph = (ph + f0 / SR) % 1.0
		src[i] = ph ** 3 - 0.25 + 0.12 * (rng.random() * 2 - 1)
	v = formant(src, vowel, shift)
	e = [0.0] * n
	for i in range(n):
		t = i / SR
		a = min(1.0, t / 0.025)
		r = 1.0 if t < dur else math.exp(-(t - dur) / 0.025)
		e[i] = a * r * math.exp(-t / (dur * 0.9))
	return mul(v, e)


def lx_laugh():
	"""Snapjaw's sing-song chuckle ('heh-heh-heh, hoo-hoo'), ring-modulated and crushed like a bad broadcast."""
	rng = R("laugh")
	out = zeros(nlen(3.9))
	# a little falling lullaby figure on 'heh'
	tune = ((0.0, 118, 0.14), (0.22, 104, 0.14), (0.44, 118, 0.14), (0.66, 98, 0.16), (0.92, 110, 0.14), (1.14, 92, 0.18))
	for s, f0, d in tune:
		m = nlen(0.1)
		clack = [a + b for a, b in zip(hp1(mul(noise(m, rng), env_ad(m, 0.0002, 0.003)), 900), damped(1450, 0.6, 0.018, m))]
		add_into(out, clack, nlen(s), 0.5)
		add_into(out, _voice(f0, f0 * 0.9, d, rng, "e"), nlen(s + 0.02), 1.0)
	add_into(out, _voice(96, 70, 0.7, rng, "o"), nlen(1.5), 1.0)
	add_into(out, _voice(84, 48, 1.1, rng, "u"), nlen(2.3), 0.8)
	y = [0.0] * len(out)
	pk = max(abs(v) for v in out) or 1.0
	for i, v in enumerate(out):
		t = i / SR
		y[i] = math.tanh(3.0 * v / pk * (0.55 + 0.45 * math.sin(TAU * 41 * t)))
	# crush: sample-and-hold + 6-bit quantize
	held = 0.0
	for i in range(len(y)):
		if i % 3 == 0:
			held = round(y[i] * 32) / 32
		y[i] = held
	y = lp1(lp1(y, 2700), 2700)
	return finish_sfx(reverb(y, 1.8, 0.35, 0.9, seed=21), -13)


def lx_wheel():
	"""The paddle wheel turning: a deep wooden groan, paddles slapping in, water pouring off."""
	rng = R("wheel")
	dur = 4.2
	n = nlen(dur)
	groan = wood(stick_slip(n, rng, 14, 38, 0.35), 0.28)
	pour = bq(noise(n, rng), "bp", 900, 0.5)
	pour = lp1(pour, 2400)
	out = [0.0] * n
	for i in range(n):
		t = i / SR
		e = 0.75 + 0.25 * math.sin(TAU * 0.24 * t)
		out[i] = 0.9 * groan[i] * e + 0.18 * pour[i] * (0.6 + 0.4 * math.sin(TAU * 0.71 * t + 1.0))
	for s in (0.3, 1.7, 3.1):
		m = nlen(0.6)
		slap = lp1(mul(noise(m, rng), env_ad(m, 0.003, 0.06)), 1100)
		thump = mul(sweep(lambda t: 60 + 50 * math.exp(-t / 0.03), m), env_ad(m, 0.002, 0.09))
		add_into(out, [a + 0.8 * b for a, b in zip(slap, thump)], nlen(s), 0.9)
		knock = wood(mul(noise(nlen(0.2), rng), env_ad(nlen(0.2), 0.0005, 0.008)), 0.5)
		add_into(out, knock, nlen(s + 0.55), 0.35)
	for i in range(n):
		t = i / SR
		out[i] *= min(1.0, t / 0.3) * min(1.0, (dur - t) / 0.6)
	return finish_sfx(reverb(out, 2.2, 0.35, 1.2, damp=0.5, seed=23), -15)


def lx_drip():
	"""One drip into still cave water."""
	rng = R("drip")
	n = nlen(0.12)
	plip = mul(sweep(lambda t: 560 + 1500 * min(1.0, t / 0.025), n), env_ad(n, 0.0008, 0.016))
	tok = mul(sweep(lambda t: 190 + 120 * math.exp(-t / 0.01), n), env_ad(n, 0.0005, 0.02))
	y = zeros(nlen(1.8))
	add_into(y, [a + 0.5 * b for a, b in zip(plip, tok)], 0)
	add_into(y, mul(sweep(lambda t: 900 + 900 * min(1.0, t / 0.02), nlen(0.05)), env_ad(nlen(0.05), 0.0005, 0.008)), nlen(0.21), 0.25)
	return finish_sfx(reverb(y, 2.6, 0.6, 1.3, damp=0.55, seed=37), -18)


def lx_lapping():
	"""Black water lapping against the hull."""
	rng = R("lapping")
	dur = 6.5
	n = nlen(dur)
	w = lp1(lp1(noise(n, rng), 700), 900)
	hi = bq(noise(n, rng), "bp", 2200, 1.2)
	out = [0.0] * n
	for i in range(n):
		t = i / SR
		sw = max(0.0, math.sin(TAU * 0.55 * t + 0.6 * math.sin(TAU * 0.13 * t))) ** 2
		out[i] = (1.6 * w[i] * (0.3 + sw) + 0.08 * hi[i] * sw) * min(1.0, t / 0.8) * min(1.0, (dur - t) / 1.0)
	for k in range(9):
		t = rng.uniform(0.3, dur - 0.5)
		d = nlen(0.05)
		b = mul(sweep(lambda tt, f0=rng.uniform(300, 600): f0 * (1 + tt / 0.05), d), env_ad(d, 0.003, 0.014))
		add_into(out, b, nlen(t), 0.12)
	return finish_sfx(reverb(out, 1.6, 0.25, 1.0, damp=0.6, seed=41), -20)


def lx_turn():
	"""Every tiny head on the mobile turns at once: one unison clockwork tick, a whirr, a sour little chime."""
	rng = R("turn")
	out = zeros(nlen(2.4))
	n = nlen(0.16)
	wh = bq(noise(n, rng), "bp", 3400, 3.0)
	wh = [v * (0.6 + 0.4 * math.sin(TAU * 90 * i / SR)) * (i / n) for i, v in enumerate(wh)]
	add_into(out, wh, 0, 0.35)
	for v in range(5):
		add_into(out, click_tpl(rng, 4200 + v * 37, 0.002, 0.03, 0.8), nlen(0.16 + rng.uniform(-0.0015, 0.0015)))
	add_into(out, wood(mul(noise(nlen(0.1), rng), env_ad(nlen(0.1), 0.0003, 0.004)), 1.6), nlen(0.16), 0.5)
	add_into(out, mbox(midi_hz(88 - 0.4), 0.7), nlen(0.2))
	add_into(out, mbox(midi_hz(94 + 0.3), 0.35), nlen(0.205))
	return finish_sfx(reverb(out, 2.0, 0.35, 0.9, seed=43), -14)


def lx_sputter():
	"""A lantern flame guttering."""
	rng = R("sputter")
	dur = 0.95
	n = nlen(dur)
	f = lp1(bq(noise(n, rng), "bp", 1300, 0.6), 3000)
	out = [0.0] * n
	g = 1.0
	for i in range(n):
		if i % 160 == 0:
			g = rng.uniform(0.2, 1.0)
		t = i / SR
		out[i] = f[i] * g * math.sin(math.pi * t / dur) ** 0.7
	for k in range(14):
		t = rng.uniform(0.02, dur - 0.1)
		add_into(out, click_tpl(rng, rng.uniform(1800, 4200), 0.0015, 0.004, rng.uniform(0.3, 0.9), 0.02), nlen(t))
	return finish_sfx(reverb(out, 0.8, 0.2, 0.5, seed=47), -19)


SFX = {
	"lx_windup": lx_windup, "lx_ratchet": lx_ratchet, "lx_creak": lx_creak, "lx_chain": lx_chain, "lx_thud": lx_thud,
	"lx_splash": lx_splash, "lx_winddown": lx_winddown, "lx_laugh": lx_laugh, "lx_wheel": lx_wheel, "lx_drip": lx_drip,
	"lx_lapping": lx_lapping, "lx_turn": lx_turn, "lx_sputter": lx_sputter,
}


# =====================================================================================  music
LOOP_S = 52.0

# the lullaby (original): (beats, midi) in 3/4; 8 bars each
PHRASE_A = [(1, 76), (1, 72), (1, 69), (2, 71), (1, 68), (1, 69), (1, 72), (1, 76), (3, 74),
	(1, 72), (1, 71), (1, 69), (1, 68), (1, 69), (1, 71), (1, 64), (1, 69), (1, 68), (3, 69)]
PHRASE_B = [(1, 76), (1, 77), (1, 76), (2, 74), (1, 72), (1, 71), (1, 72), (1, 74), (3, 76),
	(1, 81), (1, 76), (1, 72), (2, 71), (1, 74), (1, 72), (1, 71), (1, 68), (3, 69)]
# per bar: bass note on beat 1 and a soft dyad on beat 2
BARS_A = [(57, (60, 64)), (52, (56, 59)), (57, (60, 64)), (50, (57, 62)), (57, (60, 64)), (52, (56, 59)), (52, (56, 62)), (45, (57, 64))]
BARS_B = [(48, (60, 64)), (55, (59, 62)), (55, (59, 62)), (52, (56, 59)), (53, (57, 60)), (52, (56, 59)), (52, (56, 62)), (45, (57, 64))]


def _smooth(k):
	k = max(0.0, min(1.0, k))
	return 0.5 - 0.5 * math.cos(math.pi * k)


def tempo(m):
	"""Beats per second of the music box at music time m."""
	base = 1.4
	if m < 18.5:
		return base
	if m < 24.0:
		return base - 0.4 * _smooth((m - 18.5) / 5.5)
	if m < 28.1:
		return 1.0
	if m < 36.95:
		return base * (1.0 + 2.0 * ((m - 28.1) / 8.85) ** 1.6)
	if m < 43.0:
		return base * 3.0 - (base * 2.0) * _smooth((m - 36.95) / 6.05)
	return 1.0


def rate(m):
	"""Pitch factor of the music box (the tape) at music time m."""
	if m < 18.5:
		return 1.0
	if m < 26.0:
		return 1.0 - 0.16 * _smooth((m - 18.5) / 7.5)
	if m < 28.1:
		return 0.84
	if m < 36.95:
		return 1.0 + 0.25 * ((m - 28.1) / 8.85) ** 1.7
	if m < 43.0:
		return 1.25 - 0.33 * _smooth((m - 36.95) / 6.05)
	return 0.92 + 0.08 * _smooth((m - 43.0) / 8.0)


def score():
	"""Music-box events (m, midi, velocity, bright, voice) for the whole loop."""
	ev = []

	def run(m0, m1, phrases, vel_mel=0.9, vel_bass=0.55, vel_dy=0.28, mel_only=False, density=1.0, sour_from=None):
		# flatten phrases one after another (24 beats each)
		flat = []
		off = 0.0
		for ph, bb in phrases:
			beat = 0.0
			for d, mm in ph:
				flat.append((off + beat, mm, "mel"))
				beat += d
			for i, (bass, dy) in enumerate(bb):
				flat.append((off + i * 3.0, bass, "bass"))
				flat.append((off + i * 3.0 + 1.0, dy[0], "dy"))
				flat.append((off + i * 3.0 + 1.0, dy[1], "dy"))
			off += 24.0
		flat.sort()
		total = off
		beat = 0.0
		m = m0
		k = 0
		cycle = 0.0
		dm = 0.001
		rng = random.Random(int(m0 * 1000))
		while m < m1:
			while k < len(flat) and flat[k][0] + cycle <= beat:
				b, mm, kind = flat[k]
				k += 1
				if mel_only and kind != "mel":
					continue
				if density < 1.0 and rng.random() > density:
					continue
				v = {"mel": vel_mel, "bass": vel_bass, "dy": vel_dy}[kind]
				ev.append((m, mm, v * rng.uniform(0.85, 1.0), 1.0 if kind == "mel" else 0.6, "box"))
				if sour_from is not None and m >= sour_from and kind == "mel":
					ev.append((m + 0.012, mm + 6, v * 0.32 * min(1.0, (m - sour_from) / 2.0), 0.8, "sour"))
			if k >= len(flat):
				k = 0
				cycle += total
			beat += tempo(m) * dm
			m += dm

	run(0.35, 18.4, [(PHRASE_A, BARS_A)])
	run(18.5, 24.2, [(PHRASE_B, BARS_B)], 0.85, 0.5, 0.22)
	ev.append((25.6, 69 - 0.7, 0.5, 1.0, "box"))
	run(28.1, 36.95, [(PHRASE_A, BARS_A), (PHRASE_B, BARS_B)], 0.95, 0.6, 0.3, sour_from=31.0)
	run(36.95, 43.0, [(PHRASE_B, BARS_B)], 0.8, 0.45, 0.2, sour_from=36.95)
	run(43.6, 51.2, [(PHRASE_A, BARS_A)], 0.55, 0.35, 0.0, mel_only=True, density=0.8)
	return ev


def music_execution_lullaby():
	L = LOOP_S
	N = nlen(L)
	t_start = time.time()

	def q(f):
		return max(1.0, round(f * L)) / L

	def env_table(points, rate=1000):
		"""Loop-periodic piecewise-linear envelope from (time, value) points, tabulated at `rate` Hz.
		Returns a lookup function m -> value."""
		pts = list(points) + [(points[0][0] + L, points[0][1])]
		n = int(L * rate)
		tab = [0.0] * n
		j = 0
		for i in range(n):
			m = i / rate
			while j < len(pts) - 2 and m > pts[j + 1][0]:
				j += 1
			(t0, v0), (t1, v1) = pts[j], pts[j + 1]
			tab[i] = v0 + (v1 - v0) * min(1.0, max(0.0, (m - t0) / max(1e-9, t1 - t0)))
		return lambda m: tab[int(m * rate) % n]

	# ---- music box bus (output time; the note pitch follows the tape rate at its onset)
	rng = R("music")
	box = zeros(N)
	sour = zeros(N)
	ticks = zeros(N)
	evs = score()
	for m, mm, v, bright, voice in evs:
		det = rng.uniform(-22, 22) / 100.0
		f = midi_hz(mm + det) * rate(m)
		w = mbox(f, v, bright)
		add_into(sour if voice == "sour" else box, w, nlen(m + rng.uniform(-0.012, 0.012)), 1.0, wrap=True)
	# clockwork ticks on the melody beats while the box is running
	tick_rng = R("ticks")
	tick_tpls = [click_tpl(tick_rng, 3300 + 90 * i, 0.0025, 0.012, 1.0, 0.04) for i in range(4)]
	k = 0
	for m, mm, v, bright, voice in evs:
		if voice == "box" and bright == 1.0 and (m < 18.4 or 28.1 <= m < 40.0):
			add_into(ticks, tick_tpls[k % 4], nlen(m), 0.7 if k % 3 == 0 else 0.4, wrap=True)
			k += 1
	print("    box: %d notes, %d templates (%.1fs)" % (len(evs), len(_MB_CACHE), time.time() - t_start))

	# ---- tape wow / flutter: a modulated delay over the box (deeper while it drags and while it races)
	wow_depth = env_table([(0, 0.0012), (18.0, 0.0012), (22.0, 0.0045), (26.0, 0.0045), (28.1, 0.0015), (33.0, 0.004), (36.9, 0.0075), (42.0, 0.003), (50.0, 0.0012)])
	f_wow = q(0.55)
	f_flut = q(5.7)
	maxd = int(0.012 * SR) + 4
	wbox = [0.0] * N
	wsour = [0.0] * N
	for i in range(N):
		m = i / SR
		d = (wow_depth(m) * (0.5 + 0.5 * math.sin(TAU * f_wow * m)) + 0.00018 * math.sin(TAU * f_flut * m)) * SR + 2.0
		p = i - d
		j = int(math.floor(p))
		fr = p - j
		wbox[i] = box[j % N] * (1 - fr) + box[(j + 1) % N] * fr
		wsour[i] = sour[j % N] * (1 - fr) + sour[(j + 1) % N] * fr
	box, sour = wbox, wsour
	print("    wow (%.1fs)" % (time.time() - t_start))

	# ---- low drones (rendered at 4 kHz, upsampled): A1 + Bb1 beating, E2, sub A0
	DR = 4000
	nd = nlen(L, DR)
	dr = [0.0] * nd
	for f, a in ((55.0, 1.0), (58.27, 0.7), (82.41, 0.35), (27.5, 0.6)):
		fq = q(f)
		for h, ha in ((1, 1.0), (2, 0.45), (3, 0.22), (4, 0.1)):
			if f < 40 and h > 1:
				break
			s = sine(fq * h, nd, DR, ph=random.Random(int(f * h)).random() * TAU, amp=a * ha)
			dr = [x + y for x, y in zip(dr, s)]
	ed = env_table([(0, 0.45), (12, 0.55), (18.5, 0.75), (24.0, 1.0), (28.0, 0.7), (33.0, 1.0), (37.0, 1.0), (43.0, 0.6), (50.0, 0.45)])
	envd = [ed(i / DR) for i in range(nd)]
	slow = [0.75 + 0.25 * math.sin(TAU * q(1 / 13.0) * i / DR) for i in range(nd)]
	dr = [x * e * s for x, e, s in zip(dr, envd, slow)]
	drones = resample_up(dr, SR / DR, N)
	print("    drones (%.1fs)" % (time.time() - t_start))

	# ---- ghost hum ('mmm', no words) under Tumble's close-up and in the tail; at 8 kHz
	HR = 8000
	nh = nlen(L, HR)
	hum = [0.0] * nh
	eh = env_table([(0, 0.0), (11.5, 0.0), (14.0, 1.0), (18.5, 0.8), (21.0, 0.0), (44.0, 0.0), (47.0, 0.6), (50.5, 0.0)])
	for f, a in ((220.0, 1.0), (329.6, 0.6), (261.6, 0.45)):
		fq = q(f)
		vib = q(5.1)
		ph = 0.0
		for i in range(nh):
			m = i / HR
			e = eh(m)
			if e <= 0.0:
				continue
			ph += TAU * fq * (1 + 0.006 * math.sin(TAU * vib * m)) / HR
			s = math.sin(ph) + 0.3 * math.sin(2 * ph) + 0.12 * math.sin(3 * ph)
			hum[i] += a * e * s
	hum = lp1(lp1(hum, 900, HR), 900, HR)
	hum = resample_up(hum, SR / HR, N)
	print("    hum (%.1fs)" % (time.time() - t_start))

	# ---- whining cluster while the box races (m 31-37), at 8 kHz
	wh = [0.0] * nh
	for f in (1760.0, 1864.7, 2489.0):
		fq = q(f)
		s = sine(fq, nh, HR, ph=random.Random(int(f)).random() * TAU)
		wh = [x + y for x, y in zip(wh, s)]
	ew = env_table([(0, 0.0), (30.0, 0.0), (34.0, 0.8), (36.9, 1.0), (39.0, 0.0)])
	fq6 = q(6.3)
	wh = [v * ew(i / HR) * (0.7 + 0.3 * math.sin(TAU * fq6 * i / HR)) for i, v in enumerate(wh)]
	wh = resample_up(wh, SR / HR, N)

	# ---- cave bed: filtered noise swells (wind through the cavern, water). Rendered 1 s longer and the
	# overhang crossfaded into the head, so the loop seam is continuous.
	brng = R("bed")
	xf = nlen(1.0)
	bed = lp1(lp1(noise(N + xf, brng), 500), 600)
	for i in range(xf):
		a = i / xf
		bed[i] = bed[i] * a + bed[N + i] * (1 - a)
	bed = bed[:N]
	bed = [v * (0.6 + 0.4 * math.sin(TAU * q(0.11) * i / SR)) for i, v in enumerate(bed)]
	print("    bed (%.1fs)" % (time.time() - t_start))

	# ---- the spring winding tension before the restart (m 26.6-28.1): rising filtered noise
	sw = zeros(N)
	n = nlen(1.5)
	rs = R("swell")
	src = noise(n, rs)
	lo = 0.0
	for i in range(n):
		t = i / SR
		fc = 300 + 5000 * (t / 1.5) ** 2
		a = math.exp(-TAU * fc / SR)
		lo = (1 - a) * src[i] + a * lo
		sw[nlen(26.6) + i] = (src[i] - lo) * (t / 1.5) ** 2.5

	# ---- levels
	def level(x, target):
		r = rms(x)
		return scale(x, undb(target) / r) if r > 0 else x

	box = level(box, -21.0)
	sour = level(sour, -33.0) if any(sour) else sour
	ticks = level(ticks, -36.0)
	drones = level(drones, -25.0)
	hum = level(hum, -33.0)
	wh = level(wh, -38.0)
	bed = level(bed, -36.0)
	sw = level(sw, -40.0)

	dry = [a + b + c + d + e + f + g + h for a, b, c, d, e, f, g, h in zip(box, sour, ticks, drones, hum, wh, bed, sw)]
	send = [0.65 * a + 0.6 * b + 0.3 * c + 0.8 * e + 0.5 * f for a, b, c, e, f in zip(box, sour, ticks, hum, wh)]
	# reverb at 16 kHz (decimate by 2), circular so the loop seam keeps its tail
	half = [(send[i] + send[i + 1]) * 0.5 for i in range(0, N - 1, 2)]
	wet = reverb(half, 3.4, None, 1.2, damp=0.4, sr=16000, seed=4242, circular=True)
	wet = resample_up(wet, 2, N)
	print("    reverb (%.1fs)" % (time.time() - t_start))
	mixd = [a + 0.5 * b for a, b in zip(dry, wet)]

	# ---- master: DC + rumble out (circular one-pole), RMS to target through a soft clipper
	mean = sum(mixd) / N
	mixd = [v - mean for v in mixd]
	tail = mixd[-nlen(1.0):]
	pre = hp1(tail + mixd, 25.0)
	mixd = pre[len(tail):]
	g = undb(MUSIC_RMS_DB) / rms(mixd)
	for _ in range(4):
		y = [softclip(v * g) for v in mixd]
		g *= undb(MUSIC_RMS_DB) / rms(y)
	y = [softclip(v * g) for v in mixd]
	print("    master (%.1fs)" % (time.time() - t_start))
	return y


SONGS = {"execution_lullaby": music_execution_lullaby}


def describe(path):
	with wave.open(path, "rb") as w:
		n = w.getnframes()
		sr = w.getframerate()
		data = array.array("h")
		data.frombytes(w.readframes(n))
	if sys.byteorder == "big":
		data.byteswap()
	pk = max(abs(v) for v in data) / 32768.0
	r = math.sqrt(sum(v * v for v in data) / max(1, n)) / 32768.0
	seam = abs(data[0] - data[-1]) / 32768.0 if n else 0.0
	return "%-22s %6.2fs  peak %6.1f dB  rms %6.1f dB  seam-jump %.4f" % (os.path.basename(path), n / sr, db(pk), db(r), seam)


def main():
	ids = sys.argv[1:] or (list(SONGS) + list(SFX))
	rows = []
	for i in ids:
		t0 = time.time()
		if i in SONGS:
			y = SONGS[i]()
			path = os.path.join(MUSIC_DIR, i + ".wav")
		elif i in SFX:
			y = SFX[i]()
			path = os.path.join(SFX_DIR, i + ".wav")
		else:
			sys.exit("unknown id %r (music: %s; sfx: %s)" % (i, ", ".join(SONGS), ", ".join(SFX)))
		write_wav(path, y, seed=zlib.crc32(i.encode()))
		print("  rendered %s (%.1fs)" % (i, time.time() - t0))
		rows.append(describe(path))
	print()
	for r in rows:
		print(r)


if __name__ == "__main__":
	main()
