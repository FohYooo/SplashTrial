#!/usr/bin/env python3
"""
SPLASH TRIAL: Murder at Yuzu Springs -- procedural audio generator.

Renders every music track and sound effect the game uses (ids from docs/ARCHITECTURE.md section 7)
as 16-bit PCM, 32 kHz, MONO WAV files into audio/music/ and audio/sfx/. Everything is synthesized
from oscillators and noise (no samples), and fully deterministic (fixed seeds): re-running produces
identical files.

    python3 tools/gen_audio.py                 # render everything, then print the analysis table
    python3 tools/gen_audio.py trial chime     # render only these ids (music or sfx)
    python3 tools/gen_audio.py --analyze       # only analyze the existing files
    python3 tools/gen_audio.py --stems title   # print per-part levels of a song (mix balancing)
    python3 tools/gen_audio.py -j 4            # number of worker processes

Music loops are seamless: every song is rendered as a circular buffer (note/reverb/delay tails that
run past the loop end are wrapped onto the loop start, sustained drones are crossfaded, and all
filters/compressors/limiters run circularly), so AudioStreamWAV can loop end -> start without a click.
Requires numpy; scipy is used when present (much faster), with pure-numpy fallbacks otherwise.

Tracks (key, tempo, form):
    title         D minor   100 bpm  intro 4 | A 8 (call/response hook) | B 8 | A' 4  pulse lead, glass arp, bubbles+steam
    daily         F major   120 bpm  A 8 | A' 8 | B 8 | A'' 8   marimba / harp+flute, pizzicato oom-pa, clave
    tension       A minor    80 bpm  18 bars: drone, heartbeat, sparse e-piano, A-Bb pulse, clock, tremolo strings
    investigate   E minor    95 bpm  swung 16ths, chromatic bass riff, Rhodes comping, vibes / soft-lead melody
    snapjaw       G minor   116 bpm  tango (habanera tuba, accordion marcato, bandoneon + goofy bassoon, castanets)
    trial         A minor   140 bpm  intro 4 | A 8 | B 8 | A' 8 | break 4   heroic saw lead, pumping bass, 4-on-floor
    trial_climax  B minor   156 bpm  same theme, galloping bass, constant arps, choir, octave-doubled lead, tom fills
    execution     C minor   150 bpm  3/4 carnival waltz: calliope organ, tuba oom-pah-pah, detuned twin organ
    sad           B minor    72 bpm  e-piano arpeggios, strings, e-piano then flute melody
    credits       D major   108 bpm  major-key reprise of the title hook, guitar arps, warm lead + bells
    gameover      E minor    80 bpm  3/4 music-box lullaby, slightly out of tune, gong, ghost drone, wind
"""
import argparse
import math
import os
import re
import sys
import time
import wave
import zlib
from fractions import Fraction
from functools import partial

import numpy as np

try:
	from scipy.signal import lfilter as _sp_lfilter, fftconvolve as _sp_fftconvolve
except Exception:  # pragma: no cover - fallback path
	_sp_lfilter = None
	_sp_fftconvolve = None

SR = 32000
TAU = 2.0 * np.pi
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MUSIC_DIR = os.path.join(ROOT, "audio", "music")
SFX_DIR = os.path.join(ROOT, "audio", "sfx")
MUSIC_RMS_DB = -18.0      # loudness target for music (plain RMS, dBFS)
CEIL_DB = -1.0            # true sample peak ceiling for everything
NOTE_PEAK = 0.5           # every rendered note is peak-normalized to this before the part gain


# =====================================================================================  DSP core
def lfilter(b, a, x, zi=None):
	"""scipy.signal.lfilter, or a (slow) direct-form-II-transposed fallback."""
	if _sp_lfilter is not None:
		if zi is None:
			return _sp_lfilter(b, a, x)
		return _sp_lfilter(b, a, x, zi=zi)
	b = np.asarray(b, float) / a[0]
	a = np.asarray(a, float) / a[0]
	n = max(len(a), len(b))
	b = np.pad(b, (0, n - len(b)))
	a = np.pad(a, (0, n - len(a)))
	z = np.zeros(n - 1) if zi is None else np.array(zi, float)
	y = np.empty(len(x))
	for i, xi in enumerate(x):
		yi = b[0] * xi + (z[0] if n > 1 else 0.0)
		for k in range(n - 2):
			z[k] = b[k + 1] * xi + z[k + 1] - a[k + 1] * yi
		if n > 1:
			z[n - 2] = b[n - 1] * xi - a[n - 1] * yi
		y[i] = yi
	return y if zi is None else (y, z)


def fftconvolve(x, h):
	if _sp_fftconvolve is not None:
		return _sp_fftconvolve(x, h)
	n = len(x) + len(h) - 1
	nf = 1 << (n - 1).bit_length()
	return np.fft.irfft(np.fft.rfft(x, nf) * np.fft.rfft(h, nf), nf)[:n]


def nlen(sec):
	return max(1, int(round(sec * SR)))


def _t(n):
	return np.arange(n) / SR


def db(x):
	return 20.0 * math.log10(max(float(x), 1e-12))


def undb(d):
	return 10.0 ** (d / 20.0)


def rms(x):
	return float(np.sqrt(np.mean(np.square(x)) + 1e-20))


def midi_hz(m):
	return 440.0 * 2.0 ** ((m - 69.0) / 12.0)


def lp1(x, fc):
	"""One-pole lowpass."""
	fc = min(fc, SR * 0.45)
	a = math.exp(-TAU * fc / SR)
	return lfilter([1.0 - a], [1.0, -a], x)


def hp1(x, fc):
	"""One-pole highpass."""
	return x - lp1(x, fc)


def bq_coef(kind, fc, q):
	fc = min(max(float(fc), 10.0), SR * 0.49)
	w = TAU * fc / SR
	cw, sw = math.cos(w), math.sin(w)
	al = sw / (2.0 * q)
	if kind == "lp":
		b = [(1 - cw) / 2, 1 - cw, (1 - cw) / 2]
	elif kind == "hp":
		b = [(1 + cw) / 2, -(1 + cw), (1 + cw) / 2]
	else:  # band-pass, 0 dB peak gain
		b = [al, 0.0, -al]
	a = [1 + al, -2 * cw, 1 - al]
	return np.array(b) / a[0], np.array(a) / a[0]


def bq(x, kind, fc, q=0.707):
	b, a = bq_coef(kind, fc, q)
	return lfilter(b, a, x)


def bq_sweep(x, kind, fc, q=0.707, chunk=64):
	"""Time-varying biquad (cutoff array), processed in small chunks with carried state."""
	fc = np.broadcast_to(np.asarray(fc, float), x.shape)
	y = np.empty_like(x)
	zi = np.zeros(2)
	for i in range(0, len(x), chunk):
		b, a = bq_coef(kind, fc[i], q)
		y[i:i + chunk], zi = lfilter(b, a, x[i:i + chunk], zi=zi)
	return y


def circ(x, fn, pad=2.0):
	"""Run a (stateful) processor on a loop as if it had been looping forever."""
	p = min(len(x) - 1, nlen(pad))
	ext = np.concatenate([x[-p:], x, x[:p]])
	return fn(ext)[p:p + len(x)]


def circ_conv(x, h):
	"""Circular convolution (tails wrap onto the loop start)."""
	n = len(x)
	y = fftconvolve(x, h)
	out = y[:n].copy()
	rest = y[n:]
	while len(rest):
		k = min(n, len(rest))
		out[:k] += rest[:k]
		rest = rest[k:]
	return out


def fade_out(x, ms=4.0):
	k = min(len(x), max(2, int(ms * SR / 1000)))
	x = x.copy()
	x[-k:] *= np.linspace(1.0, 0.0, k)
	return x


def fade_in(x, ms=1.0):
	k = min(len(x), max(2, int(ms * SR / 1000)))
	x = x.copy()
	x[:k] *= np.linspace(0.0, 1.0, k)
	return x


def place(dst, src, t0, gain=1.0):
	"""Mix src into dst at t0 seconds; the end of src is tapered (4 ms) so truncated segments never click."""
	s = int(round(t0 * SR))
	if s >= len(dst):
		return
	e = min(len(dst), s + len(src))
	seg = np.array(src[:e - s], float) * gain
	k = min(len(seg), nlen(0.004))
	if k > 1:
		seg[-k:] *= np.linspace(1.0, 0.0, k)
	dst[s:e] += seg


def tail_fade(y, start, end):
	"""Cosine fade-out of y between start and end seconds; truncated after end."""
	a, b = nlen(start), nlen(end)
	y = y[:b].copy()
	if a < len(y):
		y[a:] *= 0.5 + 0.5 * np.cos(np.linspace(0.0, np.pi, len(y) - a))
	return y


# ---------------------------------------------------------------------------- oscillators
def phase(freq, n, ph0=0.0):
	if np.isscalar(freq):
		return (ph0 + np.arange(n) * (float(freq) / SR)) % 1.0
	return (ph0 + np.cumsum(freq) / SR) % 1.0


def _blep(ph, dt):
	out = np.zeros_like(ph)
	m = ph < dt
	x = ph[m] / dt[m]
	out[m] = x + x - x * x - 1.0
	m = ph > 1.0 - dt
	x = (ph[m] - 1.0) / dt[m]
	out[m] = x * x + x + x + 1.0
	return out


def osc_saw(freq, n, ph0=0.0):
	ph = phase(freq, n, ph0)
	dt = np.broadcast_to(np.abs(np.asarray(freq, float)) / SR, ph.shape)
	return 2.0 * ph - 1.0 - _blep(ph, dt)


def osc_pulse(freq, n, width=0.5, ph0=0.0):
	ph = phase(freq, n, ph0)
	dt = np.broadcast_to(np.abs(np.asarray(freq, float)) / SR, ph.shape)
	w = np.broadcast_to(np.asarray(width, float), ph.shape)
	y = np.where(ph < w, 1.0, -1.0)
	y = y + _blep(ph, dt) - _blep((ph - w) % 1.0, dt)
	return y - (2.0 * w - 1.0)


def osc_tri(freq, n, ph0=0.0):
	ph = phase(freq, n, ph0)
	return 4.0 * np.abs(ph - 0.5) - 1.0


def osc_sin(freq, n, ph0=0.0):
	return np.sin(TAU * phase(freq, n, ph0))


def env_adsr(n, gate, a=0.005, d=0.1, s=0.7, r=0.1):
	t = _t(n)
	a = max(a, 1e-4)
	d = max(d, 1e-4)
	r = max(r, 1e-4)
	pre = np.where(t < a, t / a, s + (1.0 - s) * np.exp(-(t - a) / d))
	eg = gate / a if gate < a else s + (1.0 - s) * math.exp(-(gate - a) / d)
	post = eg * np.exp(-(t - gate) / r)
	return np.where(t < gate, pre, post)


def ar(n, a, d):
	t = _t(n)
	return np.minimum(1.0, t / max(a, 1e-5)) * np.exp(-np.maximum(0.0, t - a) / d)


def noise(n, rng):
	return rng.standard_normal(n)


# =====================================================================================  instruments
# Every instrument: fn(freq_hz, gate_seconds, rng, **params) -> float array (any level; notes are
# peak-normalized by render_note). Drums ignore freq unless they are tuned.

def i_pad(f, gate, rng, bright=1.0):
	r = 1.0
	n = nlen(gate + 4 * r)
	t = _t(n)
	y = np.zeros(n)
	for c in (-12, -5, 5, 12):
		y += osc_saw(f * 2 ** (c / 1200), n, rng.random())
	y = bq(y, "lp", min(f * 4 * bright + 300, 2400 * bright), 0.6)
	lfo = 1.0 + 0.12 * np.sin(TAU * 0.27 * t + rng.random() * TAU)
	return y * lfo * env_adsr(n, gate, 0.55, 1.2, 0.8, r)


def i_strings(f, gate, rng, trem=0.0, bright=1.0, att=0.28):
	r = 0.5
	n = nlen(gate + 4 * r)
	t = _t(n)
	y = np.zeros(n)
	for c in (-13, -5, 4, 11):
		vib = 1 + 0.0035 * np.sin(TAU * (4.8 + rng.random()) * t + rng.random() * TAU) * np.clip(t / 0.5, 0, 1)
		y += osc_saw(f * 2 ** (c / 1200) * vib, n, rng.random())
	y = bq(y, "lp", min(f * 4 + 800, 4200 * bright), 0.5)
	y = hp1(y, 160)
	env = env_adsr(n, gate, att, 0.5, 0.85, r)
	if trem:
		env = env * (0.45 + 0.55 * np.abs(np.sin(np.pi * trem * t)))
	return y * env


def i_choir(f, gate, rng, vowel="ah"):
	forms = {"ah": ((730, 1.0, 6), (1090, 0.55, 8), (2440, 0.25, 10)),
			"oo": ((320, 1.0, 5), (800, 0.35, 7), (2240, 0.08, 9))}[vowel]
	r = 0.7
	n = nlen(gate + 4 * r)
	t = _t(n)
	y = np.zeros(n)
	for c in (-10, 0, 9):
		vib = 1 + 0.005 * np.sin(TAU * (5.0 + rng.random() * 0.6) * t + rng.random() * TAU)
		y += osc_saw(f * 2 ** (c / 1200) * vib, n, rng.random())
	out = 0.12 * lp1(y, 500)
	for fc, a, q in forms:
		out += a * bq(y, "bp", fc, q)
	return out * env_adsr(n, gate, 0.35, 0.4, 0.9, r)


def i_lead_pulse(f, gate, rng, cut=4200.0):
	r = 0.16
	n = nlen(gate + 5 * r)
	t = _t(n)
	vib = 1 + 0.0045 * np.sin(TAU * 5.4 * t) * np.clip((t - 0.16) / 0.25, 0, 1)
	fr = f * vib
	w = 0.32 + 0.12 * np.sin(TAU * 1.7 * t + rng.random() * TAU)
	y = osc_pulse(fr, n, w, rng.random()) + 0.35 * osc_saw(fr * 1.004, n, rng.random())
	y = lp1(lp1(y, cut), cut * 1.5)
	return y * env_adsr(n, gate, 0.006, 0.35, 0.75, r)


def i_lead_saw(f, gate, rng):
	r = 0.12
	n = nlen(gate + 5 * r)
	t = _t(n)
	vib = 1 + 0.005 * np.sin(TAU * 5.6 * t) * np.clip((t - 0.15) / 0.2, 0, 1)
	fr = f * vib
	y = osc_saw(fr * 2 ** (-7 / 1200), n, rng.random()) + osc_saw(fr * 2 ** (7 / 1200), n, rng.random())
	y += 0.45 * osc_pulse(fr * 0.5, n, 0.5, rng.random())
	fc = 900 + 3300 * (1 - np.exp(-t / 0.02)) * (0.55 + 0.45 * np.exp(-t / 0.3))
	y = bq_sweep(y, "lp", np.minimum(fc, 7000), 0.9)
	return y * env_adsr(n, gate, 0.008, 0.25, 0.8, r)


def i_brass(f, gate, rng):
	r = 0.1
	n = nlen(gate + 5 * r)
	t = _t(n)
	y = np.zeros(n)
	for c in (-8, 0, 8):
		y += osc_saw(f * 2 ** (c / 1200), n, rng.random())
	y += 0.5 * osc_pulse(f, n, 0.3, rng.random())
	fc = 250 + min(f * 7, 5000) * (1 - np.exp(-t / 0.035)) * (0.6 + 0.4 * np.exp(-t / 0.2))
	y = bq_sweep(y, "lp", fc, 0.8)
	return y * env_adsr(n, gate, 0.015, 0.25, 0.75, r)


def i_bell(f, gate, rng, ratio=3.5, idx=2.0, dec_mul=1.0):
	d = float(np.clip(1.6 * (523.0 / f) ** 0.45, 0.35, 4.0)) * dec_mul
	n = nlen(d * 4.5 + 0.02)
	t = _t(n)
	I = idx * np.exp(-t / (d * 0.3)) + 0.35 * idx / 2.0
	y = np.sin(TAU * f * t + I * np.sin(TAU * f * ratio * t)) * np.exp(-t / d)
	if f * 2 < 15000:
		y += 0.3 * np.sin(TAU * f * 2.0 * t) * np.exp(-t / (d * 0.35))
	if f * 5.04 < 15000:
		y += 0.12 * np.sin(TAU * f * 5.04 * t) * np.exp(-t / (d * 0.12))
	return y * np.minimum(1, t / 0.0015)


def i_epiano(f, gate, rng, bright=1.0):
	r = 0.22
	dec = float(np.clip(2.4 * (261.6 / f) ** 0.55, 0.5, 5.0))
	n = nlen(min(gate, dec * 3) + 5 * r)
	t = _t(n)
	I = bright * (1.4 * np.exp(-t / 0.25) + 0.25)
	y = np.sin(TAU * f * t + I * np.sin(TAU * f * t)) * np.exp(-t / dec)
	if f < 1000:
		tine = np.sin(TAU * f * t + 2.0 * np.exp(-t / 0.01) * np.sin(TAU * f * 13.95 * t)) * np.exp(-t / 0.06)
		y += 0.18 * bright * tine
	y *= 1 + 0.1 * np.sin(TAU * 4.8 * t)
	damp = np.where(t < gate, 1.0, np.exp(-(t - gate) / r))
	return y * damp * np.minimum(1, t / 0.0015)


def i_marimba(f, gate, rng):
	d = float(np.clip(0.5 * (261.6 / f) ** 0.6, 0.1, 1.0))
	n = nlen(d * 5)
	t = _t(n)
	y = np.sin(TAU * f * t) * np.exp(-t / d)
	if f * 3.93 < 15000:
		y += 0.25 * np.sin(TAU * f * 3.93 * t) * np.exp(-t / (d * 0.22))
	if f * 9.2 < 15000:
		y += 0.06 * np.sin(TAU * f * 9.2 * t) * np.exp(-t / (d * 0.07))
	click = lp1(noise(n, rng) * np.exp(-t / 0.0015), 3500) * 0.25
	return (y + click) * np.minimum(1, t / 0.001)


def i_pluck(f, gate, rng, bright=0.6, dec=1.0, damp=0.08, pos=0.2):
	"""Additive plucked string (perfectly tuned, alias-free): harp / guitar / pizzicato."""
	base = float(np.clip(dec * 1.1 * (220.0 / f) ** 0.55, 0.08, 4.0))
	n = nlen(min(gate + damp * 5, base * 5))
	t = _t(n)
	nh = int(min(36, 15000.0 / f))
	y = np.zeros(n)
	tilt = 1.6 - bright
	for k in range(1, nh + 1):
		a = abs(math.sin(math.pi * k * pos)) / k ** tilt
		if a < 2e-3:
			continue
		dk = base / (1.0 + 0.02 * k * k * (f / 220.0) ** 0.5)
		y += a * np.sin(TAU * f * k * t + rng.random() * 0.3) * np.exp(-t / dk)
	env = np.where(t < gate, 1.0, np.exp(-(t - gate) / damp))
	return y * env * np.minimum(1, t / 0.0008)


def i_bass_sub(f, gate, rng):
	r = 0.08
	n = nlen(gate + 5 * r)
	t = _t(n)
	y = np.sin(TAU * f * t) + 0.25 * osc_tri(f, n) + 0.12 * np.sin(TAU * 2 * f * t)
	y *= env_adsr(n, gate, 0.006, 0.4, 0.75, r)
	return np.tanh(1.2 * y)


def i_bass_saw(f, gate, rng, cut=2600.0, res=1.3, env_t=0.09):
	r = 0.05
	n = nlen(gate + 5 * r)
	t = _t(n)
	y = 0.7 * osc_saw(f, n, rng.random()) + 0.45 * osc_pulse(f * 1.004, n, 0.5, rng.random())
	fc = 180 + f * 1.5 + cut * np.exp(-t / env_t)
	y = bq_sweep(y, "lp", fc, res)
	y += 0.6 * np.sin(TAU * f * t)
	y *= env_adsr(n, gate, 0.003, 0.3, 0.7, r)
	return np.tanh(1.4 * y)


def i_bass_finger(f, gate, rng):
	damp = 0.04
	base = float(np.clip(1.6 * (55.0 / f) ** 0.3, 0.4, 2.0))
	n = nlen(gate + damp * 6)
	t = _t(n)
	y = 0.9 * np.sin(TAU * f * t) * np.exp(-t / base)
	for k in range(2, 11):
		if f * k > 12000:
			break
		a = 0.55 / k ** 1.3 * (1.0 if k % 2 else 0.8)
		y += a * np.sin(TAU * k * f * t) * np.exp(-t / (base * 0.5 / (1 + 0.15 * k)))
	y += 0.2 * lp1(noise(n, rng), 300) * np.exp(-t / 0.01)
	env = np.where(t < gate, 1.0, np.exp(-(t - gate) / damp)) * np.minimum(1, t / 0.003)
	return np.tanh(1.3 * y * env)


def i_tuba(f, gate, rng):
	r = 0.07
	n = nlen(gate + 5 * r)
	t = _t(n)
	scoop = 2 ** (-0.3 * np.exp(-t / 0.025) / 12)
	ph = phase(f * scoop, n)
	br = 0.45 + 0.55 * np.exp(-t / 0.09)
	y = (np.sin(TAU * ph) + 0.6 * br * np.sin(2 * TAU * ph) + 0.35 * br * np.sin(3 * TAU * ph)
		+ 0.18 * br * br * np.sin(4 * TAU * ph) + 0.08 * br * br * np.sin(5 * TAU * ph))
	return np.tanh(1.3 * y * env_adsr(n, gate, 0.02, 0.18, 0.7, r))


def i_organ(f, gate, rng, vib_depth=0.006, vib_rate=6.3):
	r = 0.05
	n = nlen(gate + 5 * r)
	t = _t(n)
	vib = 1 + vib_depth * np.sin(TAU * vib_rate * t + rng.random() * TAU)
	ph = phase(f * vib, n)
	y = np.zeros(n)
	for h, a in ((1, 1.0), (2, 0.7), (3, 0.45), (4, 0.3), (6, 0.15), (8, 0.1)):
		if f * h < 14000:
			y += a * np.sin(TAU * h * ph)
	y += 0.25 * lp1(osc_pulse(f * vib * 1.003, n, 0.5, rng.random()), 2500)
	y += 0.04 * bq(noise(n, rng), "bp", min(f * 3, 8000), 2)
	env = env_adsr(n, gate, 0.006, 0.08, 0.9, r)
	click = 0.15 * noise(n, rng) * np.exp(-t / 0.002)
	return y * env + click


def i_accordion(f, gate, rng):
	r = 0.06
	n = nlen(gate + 5 * r)
	t = _t(n)
	y = (osc_pulse(f * 2 ** (-8 / 1200), n, 0.3, rng.random()) + 0.8 * osc_pulse(f * 2 ** (8 / 1200), n, 0.42, rng.random())
		+ 0.3 * osc_pulse(f * 2, n, 0.35, rng.random()))
	y = bq(y, "lp", min(f * 7, 4200), 0.7)
	y = y + 0.3 * bq(y, "bp", 1300, 1.5)
	trem = 1 + 0.08 * np.sin(TAU * 5.5 * t)
	return y * trem * env_adsr(n, gate, 0.03, 0.12, 0.85, r)


def i_bassoon(f, gate, rng):
	r = 0.06
	n = nlen(gate + 5 * r)
	t = _t(n)
	vib = 1 + 0.003 * np.sin(TAU * 5.2 * t)
	y = osc_pulse(f * vib, n, 0.22, rng.random())
	y = bq(y, "lp", 1800, 0.7)
	y = 0.4 * y + bq(y, "bp", 500, 2.5) + 0.5 * bq(y, "bp", 1150, 3.5)
	return y * env_adsr(n, gate, 0.025, 0.12, 0.8, r)


def i_musicbox(f, gate, rng):
	d = float(np.clip(1.6 * (523.0 / f) ** 0.5, 0.5, 3.0))
	n = nlen(d * 4)
	t = _t(n)
	y = np.sin(TAU * f * t) * np.exp(-t / d)
	if f * 3 < 15000:
		y += 0.08 * np.sin(TAU * 3.0 * f * t) * np.exp(-t / (d * 0.3))
	if f * 5.4 < 15000:
		y += 0.3 * np.sin(TAU * 5.4 * f * t) * np.exp(-t / (d * 0.08))
	click = hp1(noise(n, rng), 2000) * np.exp(-t / 0.0012) * 0.25
	return (y + click) * np.minimum(1, t / 0.0005)


def i_glock(f, gate, rng):
	d = float(np.clip(1.2 * (784.0 / f) ** 0.4, 0.3, 2.5))
	n = nlen(d * 4)
	t = _t(n)
	y = np.sin(TAU * f * t) * np.exp(-t / d)
	for ratio, a, dm in ((2.76, 0.35, 0.25), (5.4, 0.18, 0.1), (8.93, 0.08, 0.05)):
		if f * ratio < 15000:
			y += a * np.sin(TAU * f * ratio * t) * np.exp(-t / (d * dm))
	return y * np.minimum(1, t / 0.0007)


def i_vibes(f, gate, rng):
	d = float(np.clip(2.0 * (440.0 / f) ** 0.35, 0.7, 3.5))
	r = 0.35
	n = nlen(min(gate + 5 * r, d * 4))
	t = _t(n)
	y = np.sin(TAU * f * t) * np.exp(-t / d)
	if f * 4 < 15000:
		y += 0.22 * np.sin(TAU * 4.0 * f * t) * np.exp(-t / (d * 0.12))
	y *= (1 + 0.28 * np.sin(TAU * 5.2 * t)) / 1.28
	damp = np.where(t < gate, 1.0, np.exp(-(t - gate) / r))
	return y * damp * np.minimum(1, t / 0.003)


def i_flute(f, gate, rng):
	r = 0.15
	n = nlen(gate + 5 * r)
	t = _t(n)
	vib = 1 + 0.004 * np.sin(TAU * 5.0 * t) * np.clip((t - 0.2) / 0.3, 0, 1)
	ph = phase(f * vib, n)
	y = np.sin(TAU * ph) + 0.12 * np.sin(2 * TAU * ph) + 0.05 * np.sin(3 * TAU * ph)
	breath = bq(noise(n, rng), "bp", min(f * 2, 9000), 5.0) * 0.07
	chiff = bq(noise(n, rng), "bp", min(f * 3, 10000), 2.5) * np.exp(-t / 0.03) * 0.25
	return (y + breath) * env_adsr(n, gate, 0.06, 0.2, 0.85, r) + chiff


_LOOP_T = None   # loop length (s) of the song being rendered; drones snap their frequencies to it


def _q(fr):
	"""Snap a frequency so it completes a whole number of cycles per loop (phase-continuous drones)."""
	if not _LOOP_T:
		return fr
	return max(1.0, round(fr * _LOOP_T)) / _LOOP_T


def i_drone(f, gate, rng, cut=500.0):
	n = nlen(gate + 1.0)
	t = _t(n)
	y = 0.6 * np.sin(TAU * _q(f) * t)
	for c in (-9, -3, 4, 10):
		y += osc_saw(_q(f * 2 ** (c / 1200)), n, rng.random())
	fc = cut * (1 + 0.6 * np.sin(TAU * _q(0.07) * t + rng.random() * TAU))
	y = bq_sweep(y, "lp", fc, 1.5, chunk=256)
	return y * env_adsr(n, gate, 0.02, 1.0, 1.0, 0.8)


def i_ghost(f, gate, rng):
	r = 1.5
	n = nlen(gate + 4 * r)
	t = _t(n)
	vib = 1 + 0.003 * np.sin(TAU * _q(4.0) * t + rng.random() * TAU)
	ph = phase(_q(f) * vib, n)
	ph2 = phase(_q(f * 1.004) * vib, n, 0.16)
	y = np.sin(TAU * ph) + 0.7 * np.sin(TAU * ph2) + 0.15 * np.sin(2 * TAU * ph)
	return y * env_adsr(n, gate, 1.2, 1.0, 1.0, r)


def i_bubble(f, gate, rng):
	dur = 0.05 + 0.04 * rng.random()
	n = nlen(dur * 3)
	t = _t(n)
	fr = f * (1 + 1.8 * (t / dur))
	return np.sin(TAU * np.cumsum(fr) / SR) * np.exp(-t / (dur * 0.6)) * np.minimum(1, t / 0.002)


def i_steam(f, gate, rng):
	n = nlen(gate)
	t = _t(n)
	y = bq_sweep(noise(n, rng), "bp", 1800 + 1500 * np.sin(np.pi * t / gate), 0.7, chunk=256)
	y = hp1(y, 600)
	return y * np.sin(np.pi * np.clip(t / gate, 0, 1)) ** 2


# ---------------------------------------------------------------------------- drums
def d_kick(f, gate, rng, soft=False):
	n = nlen(0.5)
	t = _t(n)
	fr = (44 if soft else 48) + (95 if soft else 130) * np.exp(-t / (0.04 if soft else 0.03)) + 50 * np.exp(-t / 0.005)
	body = np.sin(TAU * np.cumsum(fr) / SR) * np.exp(-t / (0.32 if soft else 0.26))
	click = hp1(noise(n, rng), 1200) * np.exp(-t / 0.0025) * (0.12 if soft else 0.35)
	return np.tanh(1.8 * (body + click)) * np.minimum(1, t / 0.0006)


def d_snare(f, gate, rng, brush=False):
	n = nlen(0.4)
	t = _t(n)
	tone = np.sin(TAU * np.cumsum(185 + 60 * np.exp(-t / 0.01)) / SR) * np.exp(-t / 0.055) + 0.4 * np.sin(TAU * 330 * t) * np.exp(-t / 0.03)
	nz = hp1(bq(noise(n, rng), "lp", 9000, 0.7), 1200)
	if brush:
		return (0.15 * tone + nz * ar(n, 0.006, 0.09))
	y = 0.55 * tone + 0.9 * nz * np.exp(-t / 0.12)
	return np.tanh(1.5 * y) * np.minimum(1, t / 0.0005)


def d_clap(f, gate, rng):
	n = nlen(0.35)
	t = _t(n)
	nz = bq(noise(n, rng), "bp", 1300, 1.1)
	env = np.zeros(n)
	for k, d0 in enumerate((0.0, 0.009, 0.019, 0.03)):
		env += np.where(t >= d0, np.exp(-(t - d0) / 0.0045), 0.0) * (0.9 if k < 3 else 1.0)
	env += np.where(t >= 0.03, np.exp(-(t - 0.03) / 0.11), 0.0) * 0.6
	return nz * env


def _metal(n, rng, freqs, mul):
	y = np.zeros(n)
	for fm in freqs:
		y += osc_pulse(fm * mul, n, 0.5, rng.random())
	return y


def d_hat(f, gate, rng, open_=False):
	n = nlen(0.6 if open_ else 0.12)
	t = _t(n)
	y = 0.6 * _metal(n, rng, (263, 400, 421, 474, 587, 845), 1.85) + 0.6 * noise(n, rng)
	y = bq(bq(y, "hp", 6800, 0.7), "hp", 6800, 0.7)
	return y * np.exp(-t / (0.22 if open_ else 0.032)) * np.minimum(1, t / 0.0004)


def d_shaker(f, gate, rng):
	n = nlen(0.12)
	t = _t(n)
	y = bq(noise(n, rng), "bp", 6500, 1.0)
	return y * np.minimum(1, t / 0.012) * np.exp(-np.maximum(0, t - 0.012) / 0.035)


def d_rim(f, gate, rng):
	n = nlen(0.08)
	t = _t(n)
	return (np.sin(TAU * 1750 * t) * np.exp(-t / 0.010) + 0.5 * np.sin(TAU * 520 * t) * np.exp(-t / 0.012)
		+ bq(noise(n, rng), "bp", 2500, 1.5) * np.exp(-t / 0.003))


def d_woodblock(f, gate, rng):
	f = f or 900.0
	n = nlen(0.15)
	t = _t(n)
	return (np.sin(TAU * f * t) * np.exp(-t / 0.045) + 0.4 * np.sin(TAU * f * 2.71 * t) * np.exp(-t / 0.018)
		+ 0.3 * bq(noise(n, rng), "bp", min(f * 3, 12000), 2) * np.exp(-t / 0.002))


def d_crash(f, gate, rng):
	n = nlen(2.4)
	t = _t(n)
	y = 0.4 * _metal(n, rng, (300, 427, 553, 721, 893, 1137), 2.3) + noise(n, rng)
	y = lp1(bq(bq(y, "hp", 2600, 0.7), "hp", 2600, 0.7), 11000)
	return y * (0.7 * np.exp(-t / 0.9) + 0.6 * np.exp(-t / 0.12)) * np.minimum(1, t / 0.0005)


def d_ride(f, gate, rng):
	n = nlen(1.0)
	t = _t(n)
	y = 0.6 * _metal(n, rng, (300, 427, 553, 721, 893, 1137), 3.1) + 0.5 * noise(n, rng)
	y = bq(bq(y, "hp", 4000, 0.7), "hp", 4000, 0.7)
	bell = np.sin(TAU * 3150 * t) * np.exp(-t / 0.25) * 0.3
	return (y * np.exp(-t / 0.35) + bell) * np.minimum(1, t / 0.0005)


def d_tom(f, gate, rng):
	f = f or 110.0
	n = nlen(0.6)
	t = _t(n)
	fr = f * (1 + 0.5 * np.exp(-t / 0.03))
	y = np.sin(TAU * np.cumsum(fr) / SR) * np.exp(-t / 0.22) + 0.25 * lp1(noise(n, rng), 3000) * np.exp(-t / 0.02)
	return np.tanh(1.4 * y)


def d_timpani(f, gate, rng):
	f = f or 65.0
	n = nlen(1.8)
	t = _t(n)
	ph = np.cumsum(f * (1 + 0.03 * np.exp(-t / 0.05))) / SR
	y = (np.sin(TAU * ph) * np.exp(-t / 0.8) + 0.5 * np.sin(TAU * 1.5 * ph) * np.exp(-t / 0.5)
		+ 0.25 * np.sin(TAU * 1.98 * ph) * np.exp(-t / 0.35) + 0.4 * lp1(noise(n, rng), 1200) * np.exp(-t / 0.02))
	return y * np.minimum(1, t / 0.001)


def d_castanet(f, gate, rng):
	n = nlen(0.08)
	t = _t(n)
	y = np.zeros(n)
	for d0, a in ((0.0, 1.0), (0.016, 0.6)):
		env = np.where(t >= d0, np.exp(-(t - d0) / 0.004), 0.0)
		y += a * env * (bq(noise(n, rng), "bp", 2600, 2.5) + 0.5 * np.sin(TAU * 1900 * (t - d0)))
	return y


def d_tamb(f, gate, rng):
	n = nlen(0.35)
	t = _t(n)
	y = bq(bq(0.5 * _metal(n, rng, (2200, 3100, 4300, 5200), 1.0) + noise(n, rng), "hp", 6000, 0.7), "hp", 6000, 0.7)
	env = np.zeros(n)
	for d0, a in ((0.0, 1.0), (0.006, 0.7), (0.014, 0.5)):
		env += a * np.where(t >= d0, np.exp(-(t - d0) / 0.08), 0.0)
	return y * env


def d_heart(f, gate, rng):
	n = nlen(0.7)
	y = np.zeros(n)
	for t0, a, f0 in ((0.0, 1.0, 58.0), (0.24, 0.7, 66.0)):
		m = nlen(0.3)
		tt = _t(m)
		th = np.sin(TAU * np.cumsum(f0 + 35 * np.exp(-tt / 0.02)) / SR) * np.minimum(1, tt / 0.004) * np.exp(-tt / 0.08)
		th += 0.3 * lp1(noise(m, rng), 160) * np.exp(-tt / 0.03)
		place(y, th, t0, a)
	return np.tanh(1.5 * y)


def d_swell(f, gate, rng):
	"""Reverse-cymbal riser of length `gate`, peaking right at its end."""
	n = nlen(gate)
	t = _t(n)
	y = bq_sweep(hp1(noise(n, rng), 1500), "lp", 1500 + 9000 * (t / gate) ** 2, 0.7, chunk=256)
	return fade_out(y * (t / gate) ** 2.5, 8)


def d_snap(f, gate, rng):
	n = nlen(0.06)
	t = _t(n)
	return bq(noise(n, rng), "bp", 2300, 1.6) * np.exp(-t / 0.011) + 0.6 * hp1(noise(n, rng), 4000) * np.exp(-t / 0.0015)


INSTR = {
	"pad": i_pad, "pad_warm": partial(i_pad, bright=0.7),
	"strings": i_strings, "strings_trem": partial(i_strings, trem=7.0), "strings_slow": partial(i_strings, att=0.7),
	"choir": i_choir, "choir_oo": partial(i_choir, vowel="oo"),
	"lead_pulse": i_lead_pulse, "lead_soft": partial(i_lead_pulse, cut=2300.0), "lead_saw": i_lead_saw,
	"brass": i_brass, "bell": i_bell, "glass": partial(i_bell, ratio=2.0, idx=1.0, dec_mul=0.35),
	"gong": partial(i_bell, ratio=1.41, idx=2.5, dec_mul=1.6),
	"epiano": i_epiano, "epiano_dark": partial(i_epiano, bright=0.6), "marimba": i_marimba,
	"pluck": i_pluck, "pizz": partial(i_pluck, bright=0.35, dec=0.45, damp=0.04, pos=0.3),
	"guitar": partial(i_pluck, bright=0.55, dec=1.3, pos=0.16, damp=0.12), "harp": partial(i_pluck, bright=0.5, dec=2.0, pos=0.3, damp=0.4),
	"bass_sub": i_bass_sub, "bass_saw": i_bass_saw, "bass_dark": partial(i_bass_saw, cut=900.0, env_t=0.05),
	"arp_saw": partial(i_bass_saw, cut=3200.0, env_t=0.06, res=1.0), "bass_finger": i_bass_finger,
	"pizz_bass": partial(i_pluck, bright=0.3, dec=0.6, damp=0.05, pos=0.25),
	"tuba": i_tuba, "organ": i_organ, "organ_wobble": partial(i_organ, vib_depth=0.012, vib_rate=4.2), "accordion": i_accordion, "bassoon": i_bassoon,
	"musicbox": i_musicbox, "glock": i_glock, "vibes": i_vibes, "flute": i_flute,
	"drone": i_drone, "ghost": i_ghost, "bubble": i_bubble, "steam": i_steam, "swell": d_swell,
	"kick": d_kick, "kick_soft": partial(d_kick, soft=True), "snare": d_snare, "brush": partial(d_snare, brush=True),
	"clap": d_clap, "hat_c": d_hat, "hat_o": partial(d_hat, open_=True), "shaker": d_shaker, "rim": d_rim,
	"woodblock": d_woodblock, "crash": d_crash, "ride": d_ride, "tom": d_tom, "timpani": d_timpani,
	"castanet": d_castanet, "tamb": d_tamb, "heart": d_heart, "snap": d_snap,
}

_CACHE = {}


def render_note(inst, f, gate, variant=0):
	key = (inst, round(float(f), 2), int(round(gate * 1000)), variant)
	w = _CACHE.get(key)
	if w is None:
		rng = np.random.default_rng(zlib.crc32(repr(key).encode()))
		w = np.asarray(INSTR[inst](float(f), max(gate, 0.005), rng), float)
		pk = float(np.max(np.abs(w))) if len(w) else 0.0
		if pk > 0:
			w = w * (NOTE_PEAK / pk)
		w = fade_out(w, 3).astype(np.float32)
		_CACHE[key] = w
	return w


# =====================================================================================  notation
_PC = {"c": 0, "d": 2, "e": 4, "f": 5, "g": 7, "a": 9, "b": 11}


def note_midi(tok):
	m = re.fullmatch(r"([a-g])(#|b)?(-?\d)", tok)
	if not m:
		raise ValueError("bad note %r" % tok)
	pc = _PC[m.group(1)] + (1 if m.group(2) == "#" else -1 if m.group(2) == "b" else 0)
	return 12 * (int(m.group(3)) + 1) + pc


def parse_melody(text, bpb):
	"""'r:.5 a4 d5 e5 f5:1 | ...' -> [(beat, dur, midi)], bars checked to sum to bpb.
	Durations carry over; 'a+c5' style chords use '+'; 'r' is a rest."""
	events = []
	beat = Fraction(0)
	dur = Fraction(1)
	bars = [b for b in text.split("|")]
	for bi, bar in enumerate(bars):
		toks = bar.split()
		if not toks:
			continue
		start = beat
		for tok in toks:
			if ":" in tok:
				name, d = tok.split(":")
				dur = Fraction(d) if not d.startswith(".") else Fraction("0" + d)
			else:
				name = tok
			if name != "r":
				for nm in name.split("+"):
					events.append((float(beat), float(dur), note_midi(nm)))
			beat += dur
		if beat - start != bpb:
			raise ValueError("melody bar %d has %s beats (expected %d): %r" % (bi + 1, beat - start, bpb, bar))
	return events, float(beat)


_CHORD_Q = {
	"": [0, 4, 7], "m": [0, 3, 7], "7": [0, 4, 7, 10], "m7": [0, 3, 7, 10], "maj7": [0, 4, 7, 11],
	"m9": [0, 3, 7, 10, 14], "9": [0, 4, 7, 10, 14], "dim": [0, 3, 6], "dim7": [0, 3, 6, 9], "m7b5": [0, 3, 6, 10],
	"sus4": [0, 5, 7], "sus2": [0, 2, 7], "aug": [0, 4, 8], "6": [0, 4, 7, 9], "m6": [0, 3, 7, 9],
	"add9": [0, 4, 7, 14], "7#9": [0, 4, 7, 10, 15], "maj9": [0, 4, 7, 11, 14], "7b9": [0, 4, 7, 10, 13], "5": [0, 7],
}
_RPC = {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11}


def parse_chord(sym, tr=0):
	m = re.fullmatch(r"([A-G])(#|b)?([^/]*)(?:/([A-G])(#|b)?)?", sym)
	if not m or m.group(3) not in _CHORD_Q:
		raise ValueError("bad chord %r" % sym)
	root = (_RPC[m.group(1)] + (1 if m.group(2) == "#" else -1 if m.group(2) == "b" else 0) + tr) % 12
	bass = root
	if m.group(4):
		bass = (_RPC[m.group(4)] + (1 if m.group(5) == "#" else -1 if m.group(5) == "b" else 0) + tr) % 12
	ivs = _CHORD_Q[m.group(3)]
	return {"root": root, "ivs": ivs, "bass": bass, "pcs": [(root + i) % 12 for i in ivs], "sym": sym}


def voicing(ch, center):
	notes = set()
	for pc in ch["pcs"]:
		notes.add(center - 6 + ((pc - (center - 6)) % 12))
	return sorted(notes)


# =====================================================================================  sequencer
HIT_VEL = {"X": 1.0, "x": 0.75, "o": 0.5, "g": 0.3}


class Song:
	def __init__(self, name, bpm, bars, bpb=4, swing=0.0, swing_unit=0.5, rev_time=2.0,
			rev_level=0.25, delay_beats=0.75, delay_fb=0.35, delay_level=1.0, transpose=0, seed=0):
		self.name, self.bpm, self.bars, self.bpb = name, bpm, bars, bpb
		self.swing, self.swing_unit = swing, swing_unit
		self.rev_time, self.rev_level = rev_time, rev_level
		self.delay_beats, self.delay_fb, self.delay_level = delay_beats, delay_fb, delay_level
		self.transpose = transpose
		self.parts = []
		self.segs = []          # (start_beat, dur, chord)
		self.rng = np.random.default_rng(seed + zlib.crc32(name.encode()))
		exact = bars * bpb * 60.0 / bpm * SR
		# multiple of 125 samples -> loop length in seconds is exactly representable (m/256 s)
		self.L = int(round(exact / 125.0)) * 125

	@property
	def beats(self):
		return self.bars * self.bpb

	def bb(self, bar, beat=0.0):
		return (bar - 1) * self.bpb + beat

	def time(self, beat):
		if self.swing > 0:
			u = self.swing_unit
			p = 2 * u
			k = math.floor(beat / p + 1e-9)
			fr = beat - k * p
			d = self.swing * u / 3.0
			fr2 = fr * (u + d) / u if fr <= u else (u + d) + (fr - u) * (u - d) / u
			beat = k * p + fr2
		return beat * 60.0 / self.bpm

	def prog(self, text):
		beat = self.segs[-1][0] + self.segs[-1][1] if self.segs else 0.0
		for tok in text.replace("|", " ").split():
			sym, _, d = tok.partition(":")
			dur = float(Fraction(d)) if d else float(self.bpb)
			self.segs.append((beat, dur, parse_chord(sym, self.transpose)))
			beat += dur
		return self

	def chord_at(self, beat):
		beat = beat % self.beats
		for s, d, ch in self.segs:
			if s <= beat + 1e-6 < s + d:
				return ch
		return self.segs[-1][2]

	def part(self, name, inst, **kw):
		p = Part(self, name, inst, **kw)
		self.parts.append(p)
		return p

	# ------------------------------------------------------------------ rendering
	def _duck_env(self, L):
		env = np.ones(L)
		n = nlen(0.32)
		tt = _t(n)
		shape = np.minimum(1.0, tt / 0.004) * np.exp(-tt / 0.1)
		shape[: nlen(0.004)] = np.linspace(0, 1, nlen(0.004))
		for p in self.parts:
			if not p.kick:
				continue
			for (beat, dur, midi, vel) in p.events:
				s = int(round(self.time(beat) * SR))
				idx = (s + np.arange(n)) % L
				env[idx] = np.minimum(env[idx], 1.0 - shape * min(1.0, vel))
		return env

	def render_part(self, p, L):
		prng = np.random.default_rng(zlib.crc32(("%s/%s" % (self.name, p.name)).encode()))
		notes = []
		need = L + nlen(0.5)
		for (beat, dur, midi, vel) in p.events:
			t0 = self.time(beat)
			t1 = self.time(beat + dur)
			gate = max(0.01, (t1 - t0) * p.legato)
			if midi is None:
				f = 0.0
			else:
				det = prng.uniform(-1, 1) * p.detune_rand / 100.0
				f = midi_hz(midi + det)
			variant = int(prng.integers(p.variants)) if p.variants > 1 else 0
			w = render_note(p.inst, f, gate, variant)
			v = vel * (1.0 + prng.uniform(-p.vel_rand, p.vel_rand))
			s0 = int(round(t0 * SR + prng.uniform(-1, 1) * p.human_ms * SR / 1000.0))
			if s0 < 0:
				s0 += L
			notes.append((s0, w, v))
			need = max(need, s0 + len(w))
		if p.xfade:
			need = max(need, L + nlen(p.xfade))
		buf = np.zeros(need + nlen(0.5))       # room for filter tails
		for s0, w, v in notes:
			buf[s0:s0 + len(w)] += w * v
		if p.hp:
			buf = hp1(hp1(buf, p.hp), p.hp)
		if p.lp:
			buf = lp1(lp1(buf, p.lp), p.lp)
		out = buf[:L].copy()
		if p.xfade:
			# sustained drone: blend the continuation (buf[L:]) into the loop start; drone oscillators are
			# loop-periodic (see _q), so both signals are in phase and the blend is seamless.
			X = nlen(p.xfade)
			ramp = np.linspace(0.0, 1.0, X)
			out[:X] = buf[L:L + X] * np.cos(ramp * np.pi / 2) ** 2 + buf[:X] * np.sin(ramp * np.pi / 2) ** 2
		else:
			rest = buf[L:]
			while len(rest) and np.any(rest):
				k = min(L, len(rest))
				out[:k] += rest[:k]
				rest = rest[k:]
		return out

	def render(self, stems=False):
		global _LOOP_T
		L = self.L
		_LOOP_T = L / SR
		dry = np.zeros(L)
		rsend = np.zeros(L)
		dsend = np.zeros(L)
		duck = self._duck_env(L) if any(p.duck for p in self.parts) else None
		levels = []
		for p in self.parts:
			if not p.events:
				continue
			c = self.render_part(p, L)
			if p.duck and duck is not None:
				c = c * (1.0 - p.duck * (1.0 - duck))
			c *= p.gain * undb(p.lvl) / max(1e-9, active_loud(c))
			dry += c * p.dry
			rsend += c * p.rev
			dsend += c * p.dly
			if stems:
				levels.append((p.name, rms(c), p.lvl))
		dout = np.zeros(L)
		if np.any(dsend):
			dout = circ_conv(dsend, delay_ir(self.delay_beats * 60.0 / self.bpm, self.delay_fb)) * self.delay_level
			rsend += dout * 0.35
		rout = circ_conv(rsend, reverb_ir(self.rev_time, seed=zlib.crc32(self.name.encode()) & 0xffff)) * self.rev_level
		mix = dry + dout + rout
		if stems:
			tot = rms(mix)
			print("\n[%s] mix rms %.1f dB (pre-master); reverb %.1f dB, delay %.1f dB" % (self.name, db(tot), db(rms(rout)) - db(tot), db(rms(dout) + 1e-12) - db(tot)))
			for name, r, lv in sorted(levels, key=lambda a: -a[1]):
				print("   %-12s lvl %4d  rms %6.1f dB re mix" % (name, lv, db(r) - db(tot)))
		return master_music(mix)


LVL_DEFAULT = {
	"kick": -9, "kick_soft": -10, "snare": -13, "brush": -20, "clap": -17, "hat_c": -21, "hat_o": -23, "shaker": -23,
	"tamb": -23, "rim": -21, "castanet": -19, "snap": -21, "woodblock": -20, "crash": -20, "ride": -21, "tom": -13,
	"timpani": -14, "swell": -21, "heart": -12, "bass_sub": -10, "bass_saw": -10, "bass_finger": -10, "pizz_bass": -10,
	"tuba": -10, "bass_dark": -12, "pad": -15, "pad_warm": -15, "strings": -16, "strings_slow": -16, "strings_trem": -18,
	"choir": -17, "choir_oo": -17, "drone": -13, "ghost": -18, "bubble": -24, "steam": -24,
}


def active_loud(c, win=0.1, floor_db=-30.0):
	"""K-weighted RMS of a stem measured only where it is actually sounding."""
	y = kweight(c) ** 2
	w = nlen(win)
	nb = max(1, len(y) // w)
	e = y[: nb * w].reshape(nb, w).mean(axis=1)
	act = e > e.max() * 10 ** (floor_db / 10)
	return float(np.sqrt(np.mean(e[act]))) if np.any(act) else 1e-9


class Part:
	def __init__(self, song, name, inst, lvl=None, gain=1.0, rev=0.15, dly=0.0, dry=1.0, lp=None, hp=None, duck=0.0,
			legato=0.92, human_ms=4.0, vel_rand=0.08, xfade=0.0, detune_rand=0.0, variants=None, kick=False):
		"""lvl: loudness of this part while it plays (K-weighted RMS, dB; the mix is built from these
		relative levels, then mastered). gain: extra linear trim on top."""
		self.song, self.name, self.inst = song, name, inst
		self.lvl = lvl if lvl is not None else LVL_DEFAULT.get(inst, -12.0)
		self.gain, self.rev, self.dly, self.dry = gain, rev, dly, dry
		self.lp, self.hp, self.duck, self.legato = lp, hp, duck, legato
		self.human_ms, self.vel_rand, self.xfade, self.detune_rand = human_ms, vel_rand, xfade, detune_rand
		is_drum = inst in ("kick", "kick_soft", "snare", "brush", "clap", "hat_c", "hat_o", "shaker", "rim", "crash",
			"ride", "castanet", "tamb", "snap", "heart")
		self.variants = variants if variants is not None else (4 if is_drum else 1)
		if is_drum and human_ms == 4.0:
			self.human_ms = 1.5
		self.kick = kick
		self.events = []

	def note(self, beat, dur, midi, vel=1.0):
		self.events.append((beat, dur, midi, vel))
		return self

	def long(self, bar, beat, dur, notes, vel=1.0):
		for m in notes:
			self.events.append((self.song.bb(bar, beat), dur, m + self.song.transpose, vel))
		return self

	def mel(self, bar, text, vel=0.9, oct=0, accent=True):
		evs, _ = parse_melody(text, self.song.bpb)
		b0 = self.song.bb(bar)
		bpb = self.song.bpb
		for beat, dur, m in evs:
			v = vel
			if accent:
				v *= 1.0 if abs(beat % bpb) < 1e-6 else (0.93 if abs(beat % 1) < 1e-6 else 0.85)
			self.events.append((b0 + beat, dur, m + oct + self.song.transpose, v))
		return self

	def steps(self, bars, pattern, resolve, vel=1.0, gate=None, ramp=None):
		pats = list(pattern) if isinstance(pattern, (list, tuple)) else pattern.split("|")
		pats = [p.replace(" ", "") for p in pats]
		bars = list(bars)
		for i, bar in enumerate(bars):
			pat = pats[i % len(pats)]
			n = len(pat)
			step = self.song.bpb / n
			b0 = self.song.bb(bar)
			j = 0
			while j < n:
				ch = pat[j]
				if ch in ".-":
					j += 1
					continue
				k = j + 1
				while k < n and pat[k] == "-":
					k += 1
				beat = b0 + j * step
				dur = (k - j) * step if gate is None else gate
				rv = 1.0
				if ramp is not None:
					rv = ramp[0] + (ramp[1] - ramp[0]) * ((i * n + j) / max(1, len(bars) * n - 1))
				for m, v in resolve(ch, beat, b0):
					self.events.append((beat, dur, m, v * vel * rv))
				j = k
		return self

	def hits(self, bars, pattern, vel=1.0, midi=None, gate=None, ramp=None):
		def res(ch, beat, b0):
			return [(midi, HIT_VEL[ch])] if ch in HIT_VEL else []
		return self.steps(bars, pattern, res, vel, gate, ramp)

	def bass(self, bars, pattern, lo=28, vel=1.0):
		song = self.song

		def res(ch, beat, b0):
			c = song.chord_at(beat)
			r = lo + ((c["bass"] - lo) % 12)
			third = 3 if 3 in c["ivs"] else 4
			sev = 11 if 11 in c["ivs"] else 10
			table = {"R": 0, "o": 12, "5": 7, "3": third, "7": sev, "L": -5, "6": 9, "2": 2, "4": 5}
			if ch in table:
				return [(r + table[ch], 1.0 if ch == "R" else 0.88)]
			if ch == "c":  # chromatic approach to the next bar's root
				nc = song.chord_at(b0 + song.bpb)
				r2 = lo + ((nc["bass"] - lo) % 12)
				return [(r2 - 1, 0.85)]
			return []
		return self.steps(bars, pattern, res, vel)

	def arp(self, bars, pattern, center=60, vel=1.0, gate=None):
		song = self.song

		def res(ch, beat, b0):
			if not ch.isdigit():
				return []
			c = song.chord_at(beat)
			tones = [m for m in range(center - 12, center + 36) if m % 12 in c["pcs"]]
			base = next(i for i, m in enumerate(tones) if m >= center)
			return [(tones[min(len(tones) - 1, base + int(ch))], 1.0)]
		return self.steps(bars, pattern, res, vel, gate)

	def comp(self, bars, pattern, center=60, vel=1.0, gate=None):
		song = self.song

		def res(ch, beat, b0):
			if ch not in HIT_VEL:
				return []
			return [(m, HIT_VEL[ch]) for m in voicing(song.chord_at(beat), center)]
		return self.steps(bars, pattern, res, vel, gate)

	def pad(self, bars, center=57, vel=1.0):
		bars = list(bars)
		b0, b1 = self.song.bb(bars[0]), self.song.bb(bars[-1] + 1)
		for s, d, ch in self.song.segs:
			a, e = max(s, b0), min(s + d, b1)
			if e - a > 1e-6:
				for m in voicing(ch, center):
					self.events.append((a, e - a, m, vel))
		return self

	def drone(self, notes, vel=1.0):
		"""Sustained notes spanning the whole loop (+ crossfade overlap); see render_part."""
		self.legato = 1.0
		dur = self.song.beats + (self.xfade + 1.5) * self.song.bpm / 60.0
		for m in notes:
			self.events.append((0.0, dur, m, vel))
		return self


def reverb_ir(t60, seed=7, predelay=0.018, bright=1.0):
	rng = np.random.default_rng(seed)
	n = nlen(t60 * 1.2 + 0.05)
	t = _t(n)
	x = rng.standard_normal(n)
	lo = lp1(lp1(x, 350), 350)
	hi = x - lp1(x, 2800)
	mid = x - lo - hi
	ir = lo * np.exp(-6.9 * t / (t60 * 1.2)) + mid * np.exp(-6.9 * t / t60) + 0.6 * bright * hi * np.exp(-6.9 * t / (t60 * 0.45))
	ir *= np.minimum(1.0, t / 0.025) ** 1.5
	ir = lp1(ir, 7000)
	ir /= np.sqrt(np.sum(ir ** 2))
	er = np.zeros(n)
	for _ in range(10):
		d = rng.uniform(0.006, 0.06)
		er[int(d * SR)] += rng.choice([-1.0, 1.0]) * 0.18 * (1 - d / 0.07)
	ir = ir + er
	k = len(ir) // 4
	ir[-k:] *= 0.5 + 0.5 * np.cos(np.linspace(0.0, np.pi, k))   # taper: no truncation click at the tail end
	ir = np.concatenate([np.zeros(nlen(predelay)), ir])
	return ir / np.sqrt(np.sum(ir ** 2))


def delay_ir(dt, fb, taps=9, damp=3800.0):
	D = nlen(dt)
	ir = np.zeros(D * taps + 600)
	for k in range(1, taps + 1):
		imp = np.zeros(512)
		imp[0] = fb ** (k - 1)
		imp = lp1(imp, damp / (1 + 0.35 * (k - 1)))
		ir[k * D:k * D + 512] += imp
	return ir


# =====================================================================================  mastering
def compress(x, thresh_db, ratio=2.0, att=0.008, rel=0.15, block=64):
	nb = len(x) // block + 1
	xp = np.pad(x, (0, nb * block - len(x)))
	lvl = 10 * np.log10(np.mean(xp.reshape(nb, block) ** 2, axis=1) + 1e-12)
	gr = np.maximum(0.0, lvl - thresh_db) * (1 - 1 / ratio)
	ac, rc = math.exp(-block / (att * SR)), math.exp(-block / (rel * SR))
	sm = np.empty(nb)
	g = 0.0
	for i in range(nb):
		tg = gr[i]
		c = ac if tg > g else rc
		g = tg + c * (g - tg)
		sm[i] = g
	gain = 10 ** (-sm / 20)
	return x * np.interp(np.arange(len(x)), np.arange(nb) * block + block / 2, gain)


def limiter(x, ceil, la=0.003, rel=0.06, block=16):
	"""Look-ahead brickwall limiter; returns (y, max_gain_reduction_db)."""
	from numpy.lib.stride_tricks import sliding_window_view
	nb = len(x) // block + 1
	a = np.pad(np.abs(x), (0, nb * block - len(x)))
	req = np.minimum(1.0, ceil / np.maximum(a.reshape(nb, block).max(axis=1), 1e-9))
	w = int(la * SR / block) + 1
	mn = sliding_window_view(np.pad(req, (w, w), constant_values=1.0), 2 * w + 1).min(axis=1)
	rc = math.exp(-block / (rel * SR))
	out = np.empty(nb)
	g = 1.0
	for i in range(nb):
		tg = mn[i]
		g = tg if tg < g else tg + rc * (g - tg)
		out[i] = g
	y = x * np.interp(np.arange(len(x)), np.arange(nb) * block + block / 2, out)
	return np.clip(y, -ceil, ceil), -db(out.min())


def softclip(x, k=1.3):
	return k * np.tanh(x / k)


def master_music(mix):
	x = circ(mix, lambda s: hp1(hp1(s, 25.0), 25.0), pad=2.0)
	x = x - np.mean(x)
	th = db(rms(x)) + 5.0
	x = circ(x, lambda s: compress(s, th, 2.0), pad=1.0)
	ceil = undb(CEIL_DB)
	g = undb(MUSIC_RMS_DB) / rms(x)
	for _ in range(6):
		y = circ(softclip(x * g), lambda s: limiter(s, ceil)[0], pad=0.2)
		g *= undb(MUSIC_RMS_DB) / rms(y)
	y = circ(softclip(x * g), lambda s: limiter(s, ceil)[0], pad=0.2)
	over = db(np.max(np.abs(x * g))) - CEIL_DB      # how far the raw peaks were pushed into clip+limiter
	return np.clip(y - np.mean(y), -ceil, ceil), over


def kweight(x):
	"""Approximation of the ITU-R BS.1770 K-weighting (RLB high-pass ~38 Hz + ~+4 dB shelf above ~1.7 kHz)."""
	y = bq(x, "hp", 38.0, 0.5)
	return y + 0.58 * hp1(y, 1700.0)


def st_loud(x, win=0.1):
	"""Max short-term (100 ms) K-weighted-ish RMS in dB."""
	y = kweight(x) ** 2
	w = nlen(win)
	c = np.concatenate([[0.0], np.cumsum(y)])
	if len(y) <= w:
		return 10 * math.log10(c[-1] / w + 1e-20)
	return 10 * math.log10(float(np.max(c[w:] - c[:-w])) / w + 1e-20)


def finish_sfx(x, loud=None, peak=None):
	x = np.asarray(x, float)
	x = hp1(x, 18.0)
	pk = float(np.max(np.abs(x)))
	thr = pk * undb(-62)
	idx = np.nonzero(np.abs(x) > thr)[0]
	end = min(len(x), (idx[-1] if len(idx) else len(x)) + nlen(0.01))
	x = fade_out(fade_in(x[:end], 0.4), 6)
	if loud is not None:
		x = x * undb(loud - st_loud(x))
	if peak is not None:
		x = x * (undb(peak) / float(np.max(np.abs(x))))
	ceil = undb(CEIL_DB)
	global _LAST_OVER
	_LAST_OVER = db(np.max(np.abs(x))) - CEIL_DB
	if float(np.max(np.abs(x))) > ceil:
		x, _ = limiter(softclip(x, 1.6), ceil, la=0.002, rel=0.05)
	return x


_LAST_OVER = 0.0


# =====================================================================================  music
def song_title():
	s = Song("title", 100, 24, rev_time=2.8, rev_level=0.30, delay_beats=0.75, delay_fb=0.42)
	s.prog("Dm | Bbmaj7 | Gm | Asus4:2 A:2 | Dm | Bb | F | C | Dm | Bb | Gm | A | "
		"Bb | C | Am | Dm | Gm | C | F | A7 | Dm | Bb | Gm | A")
	ALL, MAIN = range(1, 25), range(5, 25)
	s.part("pad", "pad", lvl=-15, rev=0.55).pad(ALL, center=57)
	arp = s.part("arp", "glass", lvl=-16, rev=0.35, dly=0.35)
	arp.arp(range(1, 5), "0...2...1...3...", center=62)
	arp.arp(MAIN, "0.2.1.3.2.4.3.2.", center=62)
	b = s.part("bass", "bass_sub", lvl=-10, rev=0.04)
	b.bass(range(1, 5), "R-------R-------")
	b.bass(MAIN, "R-----R-R--5--o-")
	k = s.part("kick", "kick_soft", lvl=-10, rev=0.04, kick=True)
	k.hits(MAIN, ["X.....x.x.......", "X.....x.x.......", "X.....x.x.......", "X.....x.x.....x."])
	s.part("snare", "snare", lvl=-14, rev=0.35).hits(MAIN, "....x.......x...")
	s.part("rim", "rim", lvl=-22, rev=0.3).hits(range(1, 5), "....x.......x...")
	sh = s.part("shaker", "shaker", lvl=-24, rev=0.15)
	sh.hits(range(1, 5), "x.o.x.o.x.o.x.o.")
	sh.hits(MAIN, "xoxoxoxoxoxoxoxo")
	s.part("ohat", "hat_o", lvl=-25, rev=0.2).hits(MAIN, "..............x.")
	cr = s.part("crash", "crash", lvl=-22, rev=0.3)
	for bar in (5, 13, 21):
		cr.note(s.bb(bar), 1, None, 1.0)
	sw = s.part("swell", "swell", lvl=-22, rev=0.3, legato=1.0)
	for bar in (4, 12, 20):
		sw.note(s.bb(bar, 1), 3, None, 1.0)

	A = ("r:.5 a4 d5 e5 f5:1 e5:.5 d5 | f5:1.5 d5:.5 bb4:2 | r:.5 a4 c5 d5 f5:1 e5:.5 c5 | e5:1.5 c5:.5 g4:2 | "
		"r:.5 a4 d5 e5 f5:1 g5:.5 a5 | bb5:1.5 a5:.5 f5:1 d5 | g5:1 f5:.5 e5 d5:1 bb4 | c#5:1.5 d5:.5 e5:2")
	B = ("d5:.75 f5 bb5:.5 a5:1 f5 | g5:.75 e5 c5:.5 e5:2 | a5:.75 g5 e5:.5 c5:1 e5 | d5:3 r:1 | "
		"bb5:.75 a5 g5:.5 d5:1 g5 | e5:.75 f5 g5:.5 c6:2 | a5:1 g5:.5 f5 c5:1 f5 | e5:1 g5 c#5 a4")
	A2 = ("r:.5 a4 d5 e5 f5:1 e5:.5 d5 | f5:1.5 d5:.5 bb4:2 | g5:1 f5:.5 e5 d5:1 bb4 | c#5:1.5 d5:.5 e5:2")
	lead = s.part("lead", "lead_pulse", lvl=-6, rev=0.25, dly=0.25)
	lead.mel(5, A).mel(13, B).mel(21, A2)
	bell = s.part("bell", "bell", lvl=-13, rev=0.5, dly=0.25)
	bell.mel(2, "r:2 a5:.5 d6 e6 f6").mel(4, "r:2 e6:1 c#6:1").mel(12, "r:2 a5:.5 c#6 e6 a6")
	bell.mel(16, "r:1 a5:.5 d6 e6 f6 a6:1").mel(21, A2, vel=0.55, oct=12)
	bub = s.part("bubbles", "bubble", lvl=-22, rev=0.45, variants=6)
	for bar in ALL:
		for _ in range(int(s.rng.integers(1, 4))):
			bub.note(s.bb(bar, int(s.rng.integers(0, 16)) / 4.0), 0.1, int(s.rng.integers(74, 92)), float(s.rng.uniform(0.4, 1.0)))
	st = s.part("steam", "steam", lvl=-23, rev=0.5, legato=1.0)
	for bar in (1, 5, 9, 13, 17, 21):
		st.note(s.bb(bar, 1), 6, 60, 0.9)
	return s


def song_daily():
	s = Song("daily", 120, 32, rev_time=1.6, rev_level=0.18, delay_beats=0.75, delay_fb=0.3)
	s.prog("F | Dm | Gm | C7 | F | Dm | Gm:2 C7:2 | F | F | Dm | Gm | C7 | F | Dm | Gm:2 C7:2 | F | "
		"Bb | C | Am | Dm | Gm | C | Am:2 Dm:2 | Gm:2 C7:2 | F | Dm | Gm | C7 | F | Dm | Gm | C7")
	ALL = range(1, 33)
	A = ("c5:.5 f5 a5 f5 c6:1 a5 | bb5:.5 a5 f5 d5 a5:1.5 r:.5 | g5:.5 bb5 d6 bb5 a5 g5 f5 e5 | g5:1 c5:.5 e5 g5:1 r:1 | "
		"c5:.5 f5 a5 f5 c6:1 a5 | d6:.5 c6 a5 f5 d5:1 f5 | g5:.5 a5 bb5:1 e5:.5 g5 bb5:1 | a5:1 f5:.5 c5 f5:1 r:1")
	A2 = ("c5:.5 f5 a5 f5 c6:1 a5 | bb5:.5 a5 f5 d5 a5:1.5 r:.5 | g5:.5 bb5 d6 bb5 a5 g5 f5 e5 | g5:.5 e5 c5 e5 g5 bb5 c6:1 | "
		"c5:.5 f5 a5 f5 c6:1 a5 | d6:.5 c6 a5 f5 d5:1 f5 | g5:.5 bb5 d6:1 c6:.5 bb5 g5 e5 | f5:1.5 a5:.5 c6:1 r:1")
	B = ("d5:1 f5:.5 bb5 a5:1 f5 | e5:1 g5:.5 c6 bb5:1 g5 | a5:1.5 g5:.5 e5:1 c5 | d5:2 r:2 | "
		"bb4:1 d5:.5 g5 f5:1 d5 | c5:1 e5:.5 g5 bb5:1 a5:.5 g5 | a5:1 e5 f5 a5 | g5:1 bb5 c6 e5")
	A3 = ("c5:.5 f5 a5 f5 c6:1 a5 | bb5:.5 a5 f5 d5 a5:1.5 r:.5 | g5:.5 bb5 d6 bb5 a5 g5 f5 e5 | g5:1 c5:.5 e5 g5:1 r:1 | "
		"c5:.5 f5 a5 f5 c6:1 a5 | d6:.5 c6 a5 f5 d5:1 f5 | g5:.5 a5 bb5 d6 c6 bb5 a5 g5 | e5:.5 g5 c6 bb5 g5 e5 c5 e5")
	mar = s.part("marimba", "marimba", lvl=-6, rev=0.18, dly=0.12, legato=0.8)
	mar.mel(1, A).mel(9, A2).mel(25, A3)
	mar.mel(20, "r:2 a5:.5 f5 d5 f5", vel=0.7).mel(24, "r:3 c5:.25 d5 e5 f5", vel=0.6)
	gl = s.part("glock", "glock", lvl=-14, rev=0.3, dly=0.2)
	gl.mel(9, A2, vel=0.7, oct=12)
	gl.mel(29, "c5:.5 f5 a5 f5 c6:1 a5 | d6:.5 c6 a5 f5 d5:1 f5 | g5:.5 a5 bb5 d6 c6 bb5 a5 g5 | e5:.5 g5 c6 bb5 g5 e5 c5 e5", vel=0.6, oct=12)
	pl = s.part("pluck", "harp", lvl=-6, rev=0.25, dly=0.15, legato=0.85)
	pl.mel(17, B)
	fl = s.part("flute", "flute", lvl=-13, rev=0.3)
	fl.mel(17, B, vel=0.7, oct=12)
	bs = s.part("bass", "pizz_bass", lvl=-10, rev=0.06)
	bs.bass(ALL, ["R...5...R...5...", "R...5...R...5...", "R...5...R...5...", "R...5...R...5.c."], lo=29)
	st = s.part("stabs", "pizz", lvl=-15, rev=0.15, legato=0.5)
	st.comp(ALL, "..x...x...x...x.", center=63, gate=0.22)
	s.part("kick", "kick", lvl=-10, rev=0.03, kick=True).hits(ALL, "x.......x.......")
	cl = s.part("clap", "clap", lvl=-15, rev=0.2)
	cl.hits(ALL, "....x.......x...")
	s.part("shaker", "shaker", lvl=-23, rev=0.1).hits(ALL, "x.o.x.o.x.o.x.o.")
	wb = s.part("wood", "woodblock", lvl=-19, rev=0.15, variants=1)
	wb.hits(list(range(9, 17)) + list(range(25, 33)), "x.....x.....x...|....x...x.......", midi=None)
	s.part("tamb", "tamb", lvl=-22, rev=0.15).hits(range(17, 25), "....x.......x...")
	sn = s.part("fill", "snare", lvl=-15, rev=0.2)
	sn.hits([16, 32], "............oxxX")
	cr = s.part("crash", "crash", lvl=-21, rev=0.2)
	for bar in (1, 17):
		cr.note(s.bb(bar), 1, None, 0.9)
	return s


def song_tension():
	s = Song("tension", 80, 18, rev_time=3.6, rev_level=0.38, delay_beats=1.5, delay_fb=0.45)
	s.prog("Am | Am | F | E | Am | Am | Bb | E | Am | Dm | F | E | Am | Bb | Dm | E | Am | Am")
	s.part("drone", "drone", lvl=-12, rev=0.3, xfade=3.0).drone([33, 40, 45])
	ht = s.part("heart", "heart", lvl=-11, rev=0.15, variants=2)
	ht.hits(range(1, 13), "x...............")
	ht.hits(range(13, 17), "x.......x.......")
	ht.hits(range(17, 19), "x...............")
	pn = s.part("piano", "epiano_dark", lvl=-8, rev=0.55, dly=0.35)
	pn.mel(2, "r:2 a4:1 c5:1 | b4:2 r:2 | r:1 g#4:1 e4:2")
	pn.mel(6, "r:2 a4:1 c5:1 | d5:2 bb4:2 | r:1 g#4:1 b4:1 e5:1")
	pn.mel(10, "r:2 f5:1 a5:1 | e5:2 r:2 | r:1 d5:1 b4:1 g#4:1")
	pn.mel(14, "r:2 f5:1 d5:1 | a4:2 r:1 c#5:1 | b4:1 g#4:1 e4:2")
	pn.mel(17, "r:2 a4:1 c5:1 | b4:4")
	gh = s.part("eerie", "ghost", lvl=-17, rev=0.7)
	gh.long(5, 0, 8, [76, 82]).long(7, 0, 8, [74, 80]).long(13, 0, 8, [75, 81]).long(15, 0, 8, [74, 80])
	pu = s.part("pulse", "bass_dark", lvl=-14, rev=0.2, dly=0.3, legato=0.45)
	for bar in range(5, 17):
		pu.mel(bar, "a2:.5 a2 bb2 a2 a2 a2 bb2 a2", vel=0.8 if bar < 9 else 1.0)
	ck = s.part("clock", "woodblock", lvl=-20, rev=0.3)
	for bar in range(9, 17):
		ck.mel(bar, "c6:1 g5 c6 g5", accent=False)
	stg = s.part("strings", "strings_trem", lvl=-17, rev=0.5)
	stg.long(9, 0, 16, [57, 58, 64]).long(13, 0, 16, [60, 61, 67])
	ch = s.part("choir", "choir_oo", lvl=-17, rev=0.6)
	ch.long(13, 0, 16, [45, 51])
	sw = s.part("swell", "swell", lvl=-18, rev=0.4, legato=1.0)
	for bar in (8, 12, 16):
		sw.note(s.bb(bar), 4, None, 1.0)
	tp = s.part("boom", "timpani", lvl=-12, rev=0.5)
	for bar in (9, 13):
		tp.note(s.bb(bar), 1, 33, 1.0)
	return s


def song_investigate():
	s = Song("investigate", 95, 24, swing=0.45, swing_unit=0.25, rev_time=2.0, rev_level=0.22, delay_beats=0.75, delay_fb=0.33)
	s.prog("Em7 | Em7 | Am7 | B7 | Em7 | Em7 | Am7 | B7 | Em7 | Em7 | Cmaj7 | B7 | "
		"Cmaj7 | Bm7 | Am7 | B7 | Cmaj7 | Bm7 | Am7 | B7#9 | Em7 | Em7 | Am7 | B7")
	ALL, MAIN = range(1, 25), range(5, 25)
	durs = [".75", ".25", ".5", ".5", ".25", ".75", ".5", ".5"]
	tmpl = {"m": [0, 0, 3, 5, 6, 7, 10, 12], "7": [0, 0, 4, 7, 9, 10, 7, 4], "maj7": [0, 0, 4, 7, 11, 12, 11, 7]}
	bs = s.part("bass", "bass_finger", lvl=-8, rev=0.05, legato=0.85)
	names = ["c", "c#", "d", "eb", "e", "f", "f#", "g", "ab", "a", "bb", "b"]
	for bar in ALL:
		c = s.chord_at(s.bb(bar))
		q = "maj7" if 11 in c["ivs"] else ("m" if 3 in c["ivs"] else "7")
		root = 33 + ((c["root"] - 33) % 12)
		toks = []
		for d, iv in zip(durs, tmpl[q]):
			m = root + iv
			toks.append("%s%d:%s" % (names[m % 12], m // 12 - 1, d))
		bs.mel(bar, " ".join(toks), vel=0.95)
	ep = s.part("epiano", "epiano", lvl=-14, rev=0.25, dly=0.1)
	ep.comp(range(1, 13), "o.....x.......x.", center=62, gate=0.4)
	ep.comp(range(13, 21), "x---------------", center=62)
	ep.comp(range(21, 25), "o.....x.......x.", center=62, gate=0.4)
	A = ("r:.5 b4 e5 g5 f#5:1 e5:.5 d5 | e5:2 r:1 b4:.5 d5 | e5:.5 c5 a4 c5 e5 g5:1 f#5:.5 | f#5:1.5 d#5:.5 b4:2 | "
		"r:.5 b4 e5 g5 b5:1 a5:.5 g5 | f#5:1 e5:.5 d5 e5:2 | g5:.5 e5 c5 e5 g5:1 b5 | a5:1 f#5:.5 d#5 b4:1 r:1")
	B = ("g5:.75 e5 b4:.5 c5:1 e5 | d5:.75 f#5 a5:.5 f#5:2 | e5:.75 c5 a4:.5 g5:1 e5 | f#5:1 d#5 a5 f#5 | "
		"e6:.75 d6 b5:.5 g5:1 e5 | f#5:.75 d5 b4:.5 d5:1 f#5 | a5:.75 g5 e5:.5 c5:1 a4 | b4:.5 d#5 f#5 a5 c6:1 b5")
	vb = s.part("vibes", "vibes", lvl=-7, rev=0.3, dly=0.25)
	vb.mel(5, A).mel(21, "r:.5 b4 e5 g5 f#5:1 e5:.5 d5 | e5:2 r:2", vel=0.75)
	fl = s.part("lead2", "lead_soft", lvl=-8, rev=0.3, dly=0.3)
	fl.mel(13, B)
	vb.mel(17, "e6:.75 d6 b5:.5 g5:1 e5 | f#5:.75 d5 b4:.5 d5:1 f#5 | a5:.75 g5 e5:.5 c5:1 a4 | b4:.5 d#5 f#5 a5 c6:1 b5", vel=0.5)
	s.part("pad", "strings_slow", lvl=-18, rev=0.5).pad(range(13, 21), center=55)
	k = s.part("kick", "kick", lvl=-10, rev=0.03, kick=True)
	k.hits(range(1, 5), "x...............")
	k.hits(MAIN, "x.....x..x......")
	s.part("rim", "rim", lvl=-20, rev=0.2).hits(range(1, 5), "....x.......x...")
	sn = s.part("snare", "snare", lvl=-13, rev=0.15)
	sn.hits(MAIN, ["....x.......x...", "....x.......x...", "....x.......x...", "....x.....g.xgxx"])
	s.part("ghost", "snare", lvl=-22, rev=0.1).hits(MAIN, "..g....g.g....g.")
	s.part("hat", "hat_c", lvl=-21, rev=0.05).hits(ALL, "xgxgxgxgxgxgxgxg")
	s.part("ohat", "hat_o", lvl=-24, rev=0.1).hits(MAIN, ["................", "..............x."])
	s.part("swell", "swell", lvl=-22, rev=0.3, legato=1.0).note(s.bb(12), 4, None, 1.0).note(s.bb(20), 4, None, 1.0)
	return s


def song_snapjaw():
	s = Song("snapjaw", 116, 28, rev_time=1.8, rev_level=0.22, delay_beats=0.5, delay_fb=0.25)
	s.prog("Gm | Gm | D7 | D7 | Gm | Cm | D7 | Gm | Cm | Gm | Ab | D7 | Cm | Gm | Eb:2 D7:2 | Gm | "
		"Eb | Cm | Ab | D7 | Eb | Cm | Am7b5:2 D7:2 | Gm | Gm | Ab | D7 | D7")
	ALL = range(1, 29)
	tb = s.part("tuba", "tuba", lvl=-11, rev=0.1, legato=0.7)
	tb.bass(ALL, "R--5R-5-R--5R-5-", lo=31)
	acc = s.part("stabs", "accordion", lvl=-13, rev=0.2)
	pat = "X...x...X...x..."
	end = "X.....x.x...X..."
	acc.comp(ALL, [pat] * 7 + [end] + [pat] * 7 + [end] + [pat] * 7 + [end] + [pat, pat, pat, pat], center=62, gate=0.3)
	A = ("d5:.75 eb5:.25 d5:.5 c#5 d5:1 r:.5 g4 | bb4:.75 c5:.25 bb4:.5 a4 bb4:1 r:.5 d5 | c5:.75 d5:.25 c5:.5 b4 c5 a4 f#4 a4 | "
		"d5:2 r:1 d5:.25 eb5 e5 f#5 | g5:.75 f#5:.25 g5:.5 d5 bb4:1 r:.5 g5 | g5:.75 f5:.25 eb5:.5 d5 c5:1 r:.5 eb5 | "
		"d5:.75 c5:.25 bb4:.5 a4 f#4 a4 c5 eb5 | d5:1.5 bb4:.5 g4:1 r:1")
	B = ("c4:.5 eb4 g4 c5 b4:1 c5 | d5:.5 bb4 g4 bb4 a4:1 bb4 | c5:.5 ab4 eb4 ab4 g4:1 ab4 | f#4:.5 a4 c5 d5 eb5:1 d5 | "
		"eb5:.5 d5 c5 g4 ab4 g4 f#4 g4 | bb4:1 d5 g5:2 | g5:.5 f5 eb5 bb4 a4 c5 f#5:1 | g5:1 d5:.5 bb4 g4:1 r:1")
	C = ("g5:1.5 bb5:.5 g5:1 eb5 | f5:.5 eb5 d5 c5 g5:2 | ab5:1.5 c6:.5 ab5:1 eb5 | f#5:.5 a5 c6 a5 d6:2 | "
		"g5:1.5 bb5:.5 g5:1 eb5 | f5:.5 eb5 d5 c5 eb5:1 g5 | c6:.5 a5 eb5 c5 d5 f#5 a5 c6 | bb5:1 a5:.5 g5 d5:1 r:1")
	T = "r:4 | r:2 c5:.5 r eb5 r | d5:.75 c#5:.25 d5:.5 eb5 d5 c5 a4 f#4 | a4:1 r:1 d4:.25 r d4 r a4:.5 r"
	ld = s.part("lead", "accordion", lvl=-6, rev=0.22, dly=0.12, legato=0.8)
	ld.mel(1, A).mel(17, C).mel(25, T)
	bn = s.part("bassoon", "bassoon", lvl=-7, rev=0.18, legato=0.6)
	bn.mel(9, B, oct=-12)
	pz = s.part("pizz", "pizz", lvl=-16, rev=0.2, legato=0.5)
	pz.arp(range(9, 25), "0.2.1.2.0.2.1.2.", center=67)
	cs = s.part("cast", "castanet", lvl=-16, rev=0.15)
	cs.hits(range(1, 25), "x.......x.x.x...")
	cs.hits(range(25, 29), "x.x.x...x.x.x...")
	bo = s.part("bombo", "kick_soft", lvl=-17, rev=0.1)
	bo.hits(range(1, 25), "x.......x.......")
	bo.hits(range(25, 29), "x.x.x...x.x.x...")
	sn = s.part("snap", "snap", lvl=-20, rev=0.25).hits(range(9, 17), "....x.......x...")
	cr = s.part("crash", "crash", lvl=-22, rev=0.3)
	for bar in (1, 17):
		cr.note(s.bb(bar), 1, None, 0.8)
	return s


def song_trial(climax=False):
	name = "trial_climax" if climax else "trial"
	s = Song(name, 156 if climax else 140, 32, rev_time=1.9, rev_level=0.22, delay_beats=0.75, delay_fb=0.3,
		transpose=2 if climax else 0)
	s.prog("Am | F | G | E | Am | F | G | Em | Am | F | Dm | E | F | G | Em | Am | Dm | G | C | E | "
		"Am | F | G | Em | Am | F | Dm | E | F | G | Am | E")
	ALL = range(1, 33)
	A = ("e5:.5 a5 b5 c6:1 b5:.5 a5 g5 | a5:1.5 f5:.5 c5:1 f5 | g5:.5 b5 d6 c6:1 b5:.5 a5 g5 | b5:2 g5:1 e5 | "
		"e5:.5 a5 b5 c6:1 d6:.5 e6:1 | f6:1 e6:.5 d6 c6:1 a5 | d6:1 c6:.5 a5 f5:1 d6 | e6:1.5 d6:.5 b5:1 g#5")
	B = ("c6:.75 a5 f5:.5 a5:1 c6 | d6:.75 b5 g5:.5 b5:1 d6 | e6:1.5 d6:.5 b5:1 g5 | a5:3 r:.5 e5 | "
		"f5:.75 a5 d6:.5 c6:1 a5 | b5:.75 d6 g6:.5 f6:1 d6 | e6:1 g6 e6 c6 | b5:1.5 g#5:.5 e5:1 b5")
	ld = s.part("lead", "lead_saw", lvl=-5, rev=0.2, dly=0.2)
	ld.mel(5, A).mel(13, B).mel(21, A)
	l2 = s.part("lead_lo", "brass", lvl=-12 if climax else -13, rev=0.2)
	l2.mel(21, A, oct=-12)
	if climax:
		l2.mel(5, A, oct=-12, vel=0.8).mel(13, B, oct=-12, vel=0.8)
		s.part("lead_hi", "bell", lvl=-16, rev=0.3, dly=0.2).mel(21, A, oct=12, vel=0.7)
	arp = s.part("arp", "arp_saw", lvl=-14 if climax else -15, rev=0.15, dly=0.2, legato=0.6, duck=0.5)
	if climax:
		arp.arp(ALL, "0213021302130213", center=69)
	else:
		arp.arp(list(range(1, 5)) + list(range(29, 33)), "0.2.1.2.3.2.1.2.", center=69)
		arp.arp(range(13, 21), "0.2.1.2.3.2.1.2.", center=69, vel=0.7)
	st = s.part("stabs", "brass", lvl=-12, rev=0.2, legato=0.6)
	st.comp(list(range(1, 5)) + list(range(29, 33)), "X..x..x...x.x...", center=60, gate=0.35)
	st.comp(range(5, 29), "X...............", center=60, gate=0.5, vel=0.7)
	pd = s.part("pad", "strings", lvl=-16, rev=0.4, duck=0.4)
	pd.pad(range(5, 29), center=57)
	if climax:
		s.part("choir", "choir", lvl=-17, rev=0.5, duck=0.3).pad(ALL, center=62)
	bs = s.part("bass", "bass_saw", lvl=-9, rev=0.03, duck=0.6, legato=0.8)
	bs.bass(ALL, "R-RRR-RRR-RRo-RR" if climax else "R-R-R-R-R-R-o-R-", lo=33)
	k = s.part("kick", "kick", lvl=-9.5, rev=0.03, kick=True)
	main_k = "x...x...x...x.x." if climax else "x...x...x...x..."
	k.hits(range(1, 29), main_k)
	k.hits(range(29, 32), "x.....x.x.......")
	k.hits([32], "x...............")
	sn = s.part("snare", "snare", lvl=-11, rev=0.2)
	sn.hits(range(1, 32), ["....X.......X...", "....X.......X...", "....X.......X...", "....X.......X.xx" if climax else "....X.......X..."])
	sn.hits([32], "........xxxxXXXX", ramp=(0.6, 1.1))
	s.part("clap", "clap", lvl=-17, rev=0.25).hits(range(5, 29), "....x.......x...")
	s.part("hat", "hat_c", lvl=-21, rev=0.05).hits(range(1, 29), "xoxoxoxoxoxoxoxo" if climax else "x.x.x.x.x.x.x.x.")
	s.part("ohat", "hat_o", lvl=-23, rev=0.1).hits(list(range(13, 29)) if not climax else range(1, 29), "..x...x...x...x.")
	tm = s.part("toms", "tom", lvl=-12, rev=0.2, variants=1)
	tm.mel(32, "r:2 e3:.5 c3 a2 e2", accent=False)
	if climax:
		for bar in (8, 16, 24):
			tm.mel(bar, "r:3 e3:.25 c3 a2 e2", accent=False)
		tp = s.part("timp", "timpani", lvl=-15, rev=0.4)
		for bar in range(13, 21):
			tp.note(s.bb(bar), 1, 33 + ((s.chord_at(s.bb(bar))["root"] - 33) % 12), 0.9)
	cr = s.part("crash", "crash", lvl=-19, rev=0.25)
	for bar in (1, 5, 13, 21, 29):
		cr.note(s.bb(bar), 1, None, 1.0)
	sw = s.part("swell", "swell", lvl=-19, rev=0.3, legato=1.0)
	for bar in (4, 12, 20, 28):
		sw.note(s.bb(bar, 2), 2, None, 1.0)
	sw.note(s.bb(31), 8, None, 1.0)
	return s


def song_execution():
	s = Song("execution", 150, 40, bpb=3, rev_time=1.6, rev_level=0.25, delay_beats=1.0, delay_fb=0.2)
	s.prog("Cm | Cm | G7 | G7 | Cm | G7 | G7 | Cm | Cm | Fm | G7 | Cm | Cm | G7 | G7 | Cm | Fm | Cm | G7 | Cm | "
		"Ab | Ab | Eb | Eb | Fm | Fm | G7 | G7 | Ab | Ab | Eb | Cm | Fm | Dm7b5 | G7 | G7 | Cm | Db | G7 | G7")
	ALL = range(1, 41)
	INTRO = "c5:.5 b4 c5 b4 c5 b4 | c5:.5 b4 c5 db5 c5 b4 | g5:.5 f#5 f5 e5 eb5 d5 | c#5:.5 c5 b4:1 r:1"
	A = ("g5:1 f#5 g5 | ab5:1 g5 f5 | d5:2 b4:1 | c5:3 | eb5:1 d5 eb5 | f5:1 ab5 c6 | b5:1 d6 f5 | g5:3 | "
		"g5:1 f#5 g5 | ab5:1 g5 f5 | d5:1 f5 b5 | c6:2 g5:1 | ab5:1 g5 f5 | eb5:1 d5 c5 | d5:.5 eb5 d5 c5 b4:1 | c5:2 r:1")
	B = ("c6:.5 bb5 ab5 g5 ab5:1 | eb5:2 c5:1 | bb5:.5 ab5 g5 f5 g5:1 | eb5:2 bb4:1 | c6:.5 b5 c6 db6 c6:1 | ab5:2 f5:1 | "
		"g5:.5 f#5 g5 ab5 g5 f5 | d5:1.5 r:.5 g4 b4 | c6:.5 bb5 ab5 g5 ab5:1 | eb6:2 c6:1 | bb5:.5 c6 bb5 ab5 g5:1 | "
		"g5:1 eb5 c5 | f5:.5 g5 ab5 bb5 c6:1 | d6:1 ab5 f5 | b5:.5 c6 b5 ab5 g5 f5 | d5:1 b4 g4")
	TAG = "c5:1 r:2 | db5:1 r:2 | b4:.5 c5 d5 eb5 f5 f#5 | g5:1 r:2"
	org = s.part("calliope", "organ", lvl=-6, rev=0.22, dly=0.08, legato=0.85)
	org.mel(1, INTRO).mel(5, A).mel(21, B).mel(37, TAG)
	tw = s.part("twisted", "organ", lvl=-15, rev=0.2, legato=0.85, detune_rand=0.0)
	tw.mel(5, A, oct=-12, vel=0.8).mel(21, B, oct=-12, vel=0.8)
	for i, ev in enumerate(tw.events):
		tw.events[i] = (ev[0], ev[1], ev[2] - 0.18, ev[3])  # a little flat -> queasy chorus
	gl = s.part("glock", "glock", lvl=-14, rev=0.3)
	gl.mel(21, B, oct=12, vel=0.7)
	tb = s.part("tuba", "tuba", lvl=-9, rev=0.08, legato=0.75)
	tb.bass(ALL, ["R---........", "5---........"], lo=31)
	ch = s.part("pahs", "organ", lvl=-13, rev=0.15, legato=0.6)
	ch.comp(ALL, "....x-..x-..", center=60)
	bed = s.part("bed", "organ_wobble", lvl=-19, rev=0.3, legato=1.0)
	bed.comp([b for b in ALL if b not in (37, 38)], "x-----------", center=55, vel=0.8)
	s.part("bd", "kick_soft", lvl=-14, rev=0.08).hits(ALL, "x...........")
	s.part("chick", "brush", lvl=-17, rev=0.12).hits(ALL, "....x...x...")
	s.part("tamb", "tamb", lvl=-22, rev=0.1).hits(range(21, 37), "....x...x...")
	s.part("roll", "snare", lvl=-16, rev=0.2).hits([20, 36], "xxxxxxxxxxxx", ramp=(0.3, 1.0))
	cr = s.part("crash", "crash", lvl=-21, rev=0.25)
	for bar in (5, 21, 37):
		cr.note(s.bb(bar), 1, None, 1.0)
	return s


def song_sad():
	s = Song("sad", 72, 18, rev_time=3.2, rev_level=0.40, delay_beats=1.0, delay_fb=0.3)
	s.prog("Bm | G | Bm | G | D | A | Em | G | F#sus4:2 F#:2 | Bm | G | D | A | Bm | G | D | Em:2 F#:2 | F#sus4:2 F#7:2")
	ALL = range(1, 19)
	arp = s.part("arp", "epiano", lvl=-12, rev=0.4, dly=0.15)
	arp.arp(ALL, "0-1-2-3-2-1-2-1-", center=50, vel=0.8)
	A = ("r:1 f#4:.5 b4 c#5 d5:1.5 | e5:1 d5:.5 b4 d5:2 | r:1 f#4:.5 a4 d5 e5:1.5 | f#5:1 e5:.5 c#5 e5:2 | "
		"r:1 g5:.5 f#5 e5 b4:1.5 | d5:1 e5:.5 d5 b4:2 | c#5:1 b4 a#4:2 | b4:4")
	B = ("r:1 d5:.5 g5 f#5:1 e5 | f#5:2 d5:1 a4 | e5:1.5 c#5:.5 e5:1 a5 | f#5:3 r:1 | "
		"r:1 b5:.5 a5 g5:1 d5 | f#5:1.5 e5:.5 d5:1 a4 | g5:1 e5 f#5 c#5 | b4:2 a#4:2")
	mel = s.part("melody", "epiano", lvl=-7, rev=0.45, dly=0.2)
	mel.mel(3, A, oct=12, vel=0.9)
	fl = s.part("flute", "flute", lvl=-7, rev=0.5, dly=0.2)
	fl.mel(11, B)
	sv = s.part("strmel", "strings_slow", lvl=-17, rev=0.5)
	sv.mel(11, B, oct=-12, vel=0.8)
	s.part("strings", "strings_slow", lvl=-14, rev=0.55).pad(range(3, 19), center=57)
	s.part("bass", "bass_sub", lvl=-17, rev=0.1).bass(range(3, 19), "R---------------", lo=35)
	gl = s.part("bell", "glock", lvl=-18, rev=0.6, dly=0.3)
	gl.mel(10, "r:2 f#6:1 d6:1").mel(14, "r:3 a6:1").mel(18, "r:2 c#6:1 a#5:1")
	return s


def song_credits():
	s = Song("credits", 108, 28, rev_time=2.4, rev_level=0.28, delay_beats=0.75, delay_fb=0.33)
	s.prog("D | G | Bm | A | D | G | D/F# | A | D | G | Em | A | G | A | F#m | Bm | G | A | Bm:2 G:2 | A | "
		"D | G | Bm | A | G | A | D | A")
	ALL, MAIN = range(1, 29), range(5, 29)
	A = ("r:.5 a4 d5 e5 f#5:1 e5:.5 d5 | g5:1.5 d5:.5 b4:2 | r:.5 a4 d5 e5 f#5:1 a5:.5 f#5 | e5:1.5 c#5:.5 a4:2 | "
		"r:.5 a4 d5 e5 f#5:1 g5:.5 a5 | b5:1.5 a5:.5 g5:1 d5 | g5:1 f#5:.5 e5 d5:1 b4 | c#5:1.5 d5:.5 e5:2")
	B = ("d5:.75 g5 b5:.5 a5:1 g5 | e5:.75 a5 c#6:.5 b5:1 a5 | a5:.75 f#5 c#5:.5 e5:1 f#5 | d5:3 r:1 | "
		"b5:.75 a5 g5:.5 d5:1 g5 | e5:.75 f#5 g5:.5 a5:2 | f#5:1 d5 g5 b5 | a5:2 g5:1 e5")
	A2 = ("r:.5 a4 d5 e5 f#5:1 e5:.5 d5 | g5:1.5 d5:.5 b4:2 | r:.5 f#4 b4 c#5 d5:1 f#5:.5 d5 | e5:1.5 c#5:.5 a4:2 | "
		"b4:.5 d5 g5 a5 b5:1 a5:.5 g5 | a5:1 c#6 e6 c#6 | d6:3 r:1 | c#6:2 a5:2")
	ld = s.part("lead", "lead_soft", lvl=-6, rev=0.25, dly=0.2)
	ld.mel(5, A).mel(13, B).mel(21, A2)
	bl = s.part("bell", "bell", lvl=-13, rev=0.45, dly=0.25)
	bl.mel(1, "r:.5 a5 d6 e6 f#6:2 | r:4 | r:.5 f#5 b5 c#6 d6:2 | r:2 e6:1 c#6:1")
	bl.mel(16, "r:1 a5:.5 d6 e6 f#6 a6:1").mel(21, A2, oct=12, vel=0.55)
	gt = s.part("guitar", "guitar", lvl=-13, rev=0.25, dly=0.1)
	gt.arp(ALL, "0-1-2-3-4-3-2-1-", center=55)
	s.part("pad", "pad_warm", lvl=-15, rev=0.5).pad(ALL, center=57)
	s.part("strings", "strings", lvl=-17, rev=0.5).pad(range(21, 29), center=64)
	s.part("bass", "bass_finger", lvl=-10, rev=0.05).bass(MAIN, "R-----R-R---5---", lo=33)
	s.part("bass_in", "bass_finger", lvl=-12, rev=0.05).bass(range(1, 5), "R---------------", lo=33)
	k = s.part("kick", "kick", lvl=-10, rev=0.03, kick=True)
	k.hits(MAIN, ["x.....x.x.......", "x.....x.x.......", "x.....x.x.......", "x.....x.x.....x."])
	s.part("snare", "snare", lvl=-13, rev=0.25).hits(MAIN, "....x.......x...")
	s.part("hat", "hat_c", lvl=-21, rev=0.05).hits(MAIN, "x.x.x.x.x.x.x.x.")
	s.part("shaker", "shaker", lvl=-23, rev=0.1).hits(range(1, 5), "x.o.x.o.x.o.x.o.")
	s.part("tamb", "tamb", lvl=-22, rev=0.1).hits(range(13, 21), "....x.......x...")
	cr = s.part("crash", "crash", lvl=-21, rev=0.3)
	for bar in (5, 13, 21):
		cr.note(s.bb(bar), 1, None, 0.9)
	s.part("swell", "swell", lvl=-22, rev=0.3, legato=1.0).note(s.bb(12, 2), 2, None, 1.0).note(s.bb(20, 2), 2, None, 1.0)
	return s


def song_gameover():
	s = Song("gameover", 80, 20, bpb=3, rev_time=3.0, rev_level=0.42, delay_beats=1.5, delay_fb=0.35)
	s.prog("Em | Em | Am | B7 | Em | C | Am6 | B7 | Em | Em | C | B7 | Am | Em | Cm | B7 | Em | Em | Am | B7")
	MEL = ("b4:1 e5 g5 | f#5:1.5 e5:.5 d#5:1 | e5:1 a4 c5 | b4:2 r:1 | b4:1 e5 g5 | a5:1.5 g5:.5 e5:1 | f#5:1 e5 c5 | d#5:2 b4:1 | "
		"g5:1 f#5 e5 | b5:2 g5:1 | c6:1 b5 a5 | f#5:2 a5:1 | c6:1 b5:.5 a5 e5:1 | g5:1.5 f#5:.5 e5:1 | c5:1 eb5 g5 | f#5:1 d#5 b4 | "
		"e5:3 | r:3 | c5:1 b4 a4 | b4:1.5 a4:.5 f#4:1")
	mb = s.part("musicbox", "musicbox", lvl=-6, rev=0.4, dly=0.2, detune_rand=10.0)
	mb.mel(1, MEL)
	acc = s.part("box_low", "musicbox", lvl=-11, rev=0.4, detune_rand=12.0)
	acc.arp(list(range(1, 17)) + [19, 20], "0---1---2---", center=52)
	acc.arp([17, 18], "0-----------", center=52)
	bl = s.part("bell", "gong", lvl=-15, rev=0.6)
	for bar in (1, 5, 9, 13, 17):
		bl.note(s.bb(bar), 2, 40, 0.9)
	s.part("drone", "ghost", lvl=-16, rev=0.4, xfade=3.0).drone([40, 47])
	wn = s.part("wind", "steam", lvl=-24, rev=0.5, legato=1.0)
	for bar in (2, 9, 15):
		wn.note(s.bb(bar), 9, 60, 0.8)
	return s


SONGS = {
	"title": song_title, "daily": song_daily, "tension": song_tension, "investigate": song_investigate,
	"snapjaw": song_snapjaw, "trial": song_trial, "trial_climax": partial(song_trial, True),
	"execution": song_execution, "sad": song_sad, "credits": song_credits, "gameover": song_gameover,
}


# =====================================================================================  SFX
def _rng(name):
	return np.random.default_rng(zlib.crc32(("sfx/" + name).encode()))


def room(x, t60=0.8, mix=0.2, seed=3, bright=1.0):
	ir = reverb_ir(t60, seed=seed, predelay=0.008, bright=bright)
	wet = fftconvolve(x, ir)
	out = np.zeros(len(wet))
	out[:len(x)] += x
	return out + wet * mix


def tone_bell(f, dur, dec, ratio=3.0, idx=1.5, rng=None):
	n = nlen(max(dur, dec * 6.5))
	t = _t(n)
	I = idx * np.exp(-t / (dec * 0.25))
	y = np.sin(TAU * f * t + I * np.sin(TAU * f * ratio * t)) * np.exp(-t / dec)
	if f * 2 < 15000:
		y += 0.3 * np.sin(TAU * 2 * f * t) * np.exp(-t / (dec * 0.4))
	return y * np.minimum(1, t / 0.001)


def chirp_sine(f0, f1, dur, dec, n=None):
	n = n or nlen(dur)
	t = _t(n)
	fr = f0 * (f1 / f0) ** np.clip(t / dur, 0, 1)
	return np.sin(TAU * np.cumsum(fr) / SR) * np.exp(-t / dec) * np.minimum(1, t / 0.001)


def bubbles(out, rng, count, t0, t1, fmin=500, fmax=1800, amp=0.3, decay_with_time=True):
	for _ in range(count):
		tt = rng.uniform(t0, t1)
		f = rng.uniform(fmin, fmax)
		d = rng.uniform(0.02, 0.05)
		a = amp * rng.uniform(0.4, 1.0) * ((1 - (tt - t0) / max(1e-6, t1 - t0)) * 0.7 + 0.3 if decay_with_time else 1)
		place(out, chirp_sine(f, f * rng.uniform(1.6, 2.6), d * 1.5, d, nlen(d * 4)), tt, a)


def pings(out, rng, count, t0, t1, fmin, fmax, amp, dmin=0.03, dmax=0.12, early=2.0):
	for _ in range(count):
		u = rng.random() ** early
		tt = t0 + (t1 - t0) * u
		f = rng.uniform(fmin, fmax)
		d = rng.uniform(dmin, dmax)
		n = nlen(d * 5)
		t = _t(n)
		y = np.sin(TAU * f * t) + (0.5 * np.sin(TAU * f * 2.76 * t) if f * 2.76 < 15500 else 0)
		y = y * np.exp(-t / d) * np.minimum(1, t / 0.0005)
		place(out, y, tt, amp * rng.uniform(0.4, 1.0) * (1 - 0.7 * u))


def sfx_blip():
	n = nlen(0.032)
	t = _t(n)
	ph = np.cumsum(760 * (1 + 0.18 * t / 0.032)) / SR
	y = (np.sin(TAU * ph) + 0.18 * np.sin(2 * TAU * ph)) * np.minimum(1, t / 0.0015) * np.exp(-t / 0.009)
	return finish_sfx(fade_out(y, 6), peak=-6.0)


def sfx_select():
	n = nlen(0.08)
	t = _t(n)
	f = 1250 + 450 * np.minimum(1, t / 0.02)
	y = np.sin(TAU * np.cumsum(f) / SR) * np.minimum(1, t / 0.002) * np.exp(-t / 0.022)
	y += 0.25 * np.sin(TAU * np.cumsum(f * 2) / SR) * np.exp(-t / 0.01)
	return finish_sfx(y, loud=-21)


def sfx_confirm():
	out = np.zeros(nlen(0.9))
	for t0, f, a in ((0.0, 1318.5, 0.8), (0.075, 1975.5, 1.0)):
		place(out, tone_bell(f, 0.5, 0.12, ratio=2.0, idx=0.8), t0, a)
	return finish_sfx(room(out, 0.6, 0.15), loud=-17)


def sfx_cancel():
	out = np.zeros(nlen(0.4))
	for t0, f, a in ((0.0, 880.0, 1.0), (0.085, 659.3, 0.9)):
		n = nlen(0.25)
		t = _t(n)
		y = (np.sin(TAU * f * t) + 0.2 * np.sin(TAU * 3 * f * t)) * np.minimum(1, t / 0.002) * np.exp(-t / 0.06)
		place(out, y, t0, a)
	return finish_sfx(room(out, 0.4, 0.12), loud=-19)


def sfx_clue():
	rng = _rng("clue")
	out = np.zeros(nlen(3.4))
	for i, f in enumerate((1046.5, 1318.5, 1568.0, 2093.0)):
		place(out, render_note("glock", f, 0.3), 0.07 * i, 0.7 + 0.1 * i)
	for f in (1046.5, 1318.5, 1568.0, 2093.0):
		tb = tone_bell(f, 1.2, 0.45, ratio=3.0, idx=0.6)
		trem = 0.75 + 0.25 * np.sin(TAU * 9 * _t(len(tb)))
		place(out, tb * trem, 0.29, 0.35)
	pings(out, rng, 14, 0.25, 0.9, 3000, 7000, 0.18, 0.02, 0.06, early=1.0)
	return finish_sfx(room(tail_fade(out, 1.3, 2.5), 1.2, 0.25), loud=-15)


def sfx_chime():
	out = np.zeros(nlen(3.6))
	for t0, f in ((0.0, 659.3), (0.45, 523.3)):
		n = nlen(3.1)
		t = _t(n)
		y = (np.sin(TAU * f * t + 0.8 * np.exp(-t / 0.2) * np.sin(TAU * f * 2.0 * t)) * np.exp(-t / 1.3)
			+ 0.35 * np.sin(TAU * f * 0.5 * t) * np.exp(-t / 1.6) + 0.25 * np.sin(TAU * f * 3.0 * t) * np.exp(-t / 0.3)
			+ 0.12 * np.sin(TAU * f * 4.2 * t) * np.exp(-t / 0.12))
		y *= np.minimum(1, t / 0.003)
		place(out, tail_fade(y, 1.9, 3.1), t0, 1.0)
	return finish_sfx(room(out, 1.6, 0.3), loud=-15)


def sfx_body_found():
	rng = _rng("body_found")
	out = np.zeros(nlen(3.4))
	short = [36, 48, 51, 55, 60]
	for t0 in (0.0, 0.30):
		for m in short:
			place(out, render_note("brass", midi_hz(m), 0.16), t0, 0.5)
		place(out, render_note("timpani", midi_hz(36), 0.3, 1), t0, 1.2)
		place(out, render_note("kick", 0, 0.2, 2), t0, 0.8)
	t0 = 0.60
	for m in (36, 48, 54, 58, 63, 69):
		place(out, render_note("brass", midi_hz(m), 1.15), t0, 0.5)
	for m in (81, 82):
		place(out, render_note("strings_trem", midi_hz(m), 1.0), t0, 0.22)
	place(out, render_note("timpani", midi_hz(36), 1.0, 3), t0, 1.4)
	place(out, render_note("kick", 0, 0.2, 1), t0, 1.0)
	place(out, render_note("crash", 0, 1.0, 0), t0, 0.6)
	n = nlen(1.6)
	t = _t(n)
	place(out, np.sin(TAU * np.cumsum(30 + 50 * np.exp(-t / 0.15)) / SR) * np.exp(-t / 0.6), t0, 0.9)
	y = tail_fade(room(out, 2.0, 0.32), 2.2, 2.95)
	return finish_sfx(y, loud=-11)


def sfx_whoosh():
	rng = _rng("whoosh")
	n = nlen(0.5)
	t = _t(n)
	fc = 300 + 2800 * np.sin(np.pi * np.clip(t / 0.46, 0, 1)) ** 1.5
	y = bq_sweep(noise(n, rng), "bp", fc, 1.2)
	env = np.where(t < 0.2, (t / 0.2) ** 2, np.exp(-(t - 0.2) / 0.09))
	return finish_sfx(y * env, loud=-16)


def sfx_shout():
	rng = _rng("shout")
	out = np.zeros(nlen(1.2))
	n = nlen(0.13)
	t = _t(n)
	place(out, bq_sweep(noise(n, rng), "bp", 800 + 4200 * (t / 0.13) ** 2, 1.0) * (t / 0.13) ** 2, 0.0, 0.6)
	t0 = 0.12
	for m in (48, 55, 60, 63, 67):
		place(out, render_note("brass", midi_hz(m), 0.22), t0, 0.45)
	place(out, render_note("kick", 0, 0.2, 0), t0, 1.0)
	place(out, render_note("crash", 0, 0.5, 1), t0, 0.35)
	place(out, tone_bell(2637.0, 0.8, 0.35, ratio=1.41, idx=3.0), t0, 0.35)
	return finish_sfx(room(out, 0.9, 0.22), loud=-12)


def sfx_shoot():
	rng = _rng("shoot")
	out = np.zeros(nlen(0.5))
	n = nlen(0.32)
	t = _t(n)
	x = noise(n, rng)
	fc = 900 + 1800 * (1 - np.exp(-t / 0.03))
	am = np.clip(0.75 + 0.6 * lp1(noise(n, rng), 70) * 4, 0.25, 1.3)
	y = (bq_sweep(x, "bp", fc, 2.2) + 0.35 * hp1(x, 3500)) * am * np.minimum(1, t / 0.004) * np.exp(-t / 0.09)
	place(out, y, 0.0, 1.0)
	place(out, chirp_sine(1500, 650, 0.08, 0.03, nlen(0.2)), 0.0, 0.35)
	bubbles(out, rng, 6, 0.08, 0.3, 900, 2200, 0.18)
	return finish_sfx(room(out, 0.4, 0.1), loud=-14)


def sfx_break():
	rng = _rng("break")
	out = np.zeros(nlen(2.2))
	place(out, render_note("kick", 0, 0.2, 3), 0.0, 0.9)
	n = nlen(1.2)
	t = _t(n)
	place(out, hp1(noise(n, rng), 1800) * np.exp(-t / 0.2) * np.minimum(1, t / 0.0008), 0.0, 0.55)
	pings(out, rng, 48, 0.0, 0.5, 2200, 9000, 0.32, 0.02, 0.11, early=2.2)
	sp = bq_sweep(noise(n, rng), "lp", 700 + 5000 * np.exp(-t / 0.15), 0.9) * np.minimum(1, t / 0.008) * np.exp(-t / 0.3)
	place(out, sp, 0.02, 0.7)
	bubbles(out, rng, 16, 0.1, 0.95, 500, 1700, 0.22)
	place(out, tone_bell(3136.0, 1.0, 0.45, ratio=1.41, idx=2.5), 0.0, 0.3)
	return finish_sfx(room(out, 1.4, 0.3), loud=-11)


def sfx_wrong():
	out = np.zeros(nlen(0.6))
	for t0, dur, bend in ((0.0, 0.16, 0.0), (0.21, 0.30, -1.5)):
		n = nlen(dur)
		t = _t(n)
		fr = 110.0 * 2 ** (bend * (t / dur) / 12)
		y = osc_pulse(fr, n, 0.5) + 0.7 * osc_saw(fr * 1.03, n)
		y = np.tanh(2.0 * lp1(y, 1800))
		y *= np.minimum(1, t / 0.004) * np.clip((dur - t) / 0.02, 0, 1)
		place(out, y, t0, 1.0)
	return finish_sfx(out, loud=-15)


def sfx_pop():
	rng = _rng("pop")
	n = nlen(0.1)
	t = _t(n)
	f = 500 * (1 + 3 * np.minimum(1, t / 0.03))
	y = np.sin(TAU * np.cumsum(f) / SR) * np.exp(-t / 0.02) * np.minimum(1, t / 0.0008)
	y += hp1(noise(n, rng), 2000) * np.exp(-t / 0.0008) * 0.6
	return finish_sfx(y, loud=-16)


def sfx_tick():
	rng = _rng("tick")
	n = nlen(0.05)
	t = _t(n)
	y = (np.sin(TAU * 2400 * t) * np.exp(-t / 0.006) + 0.6 * np.sin(TAU * 4100 * t) * np.exp(-t / 0.003)
		+ bq(noise(n, rng), "bp", 3000, 2) * np.exp(-t / 0.002))
	return finish_sfx(y * np.minimum(1, t / 0.0004), loud=-21)


def sfx_heartbeat():
	rng = _rng("heartbeat")
	out = np.zeros(nlen(0.9))
	for t0, a, f0 in ((0.0, 1.0, 62.0), (0.2, 0.75, 70.0)):
		n = nlen(0.3)
		t = _t(n)
		y = np.sin(TAU * np.cumsum(f0 + 40 * np.exp(-t / 0.02)) / SR) * np.minimum(1, t / 0.004) * np.exp(-t / 0.085)
		y += 0.4 * lp1(noise(n, rng), 150) * np.exp(-t / 0.03)
		place(out, tail_fade(y, 0.2, 0.3), t0, a)
	return finish_sfx(np.tanh(1.6 * lp1(out, 400)), loud=-13)


def _wood(n, rng, modes, imp=0.8):
	t = _t(n)
	y = np.zeros(n)
	for f, a, d in modes:
		y += a * np.sin(TAU * f * t) * np.exp(-t / d)
	y += imp * bq(noise(n, rng), "bp", 1800, 0.8) * np.exp(-t / 0.006)
	return y * np.minimum(1, t / 0.0004)


def sfx_gavel():
	rng = _rng("gavel")
	n = nlen(0.4)
	t = _t(n)
	y = _wood(n, rng, ((190, 0.9, 0.09), (510, 0.6, 0.05), (1130, 0.45, 0.03), (2350, 0.25, 0.015), (3900, 0.12, 0.008)))
	y += 0.6 * np.sin(TAU * 90 * t) * np.exp(-t / 0.06)
	return finish_sfx(room(np.tanh(1.3 * y), 0.8, 0.22), loud=-13)


def sfx_slot():
	rng = _rng("slot")
	n = nlen(0.07)
	t = _t(n)
	y = (bq(noise(n, rng), "bp", 4500, 1.0) * np.exp(-t / 0.002) + 0.5 * np.sin(TAU * 2900 * t) * np.exp(-t / 0.018)
		+ 0.4 * np.sin(TAU * 700 * t) * np.exp(-t / 0.008))
	return finish_sfx(y * np.minimum(1, t / 0.0003), loud=-20)


def sfx_drumroll():
	rng = _rng("drumroll")
	dur = 2.4
	out = np.zeros(nlen(dur + 0.4))
	times = np.arange(0, dur, 1 / 24.0)
	for i, tt in enumerate(times):
		tt += rng.uniform(-0.003, 0.003)
		a = (0.22 + 0.78 * (tt / dur) ** 1.6) * (0.88 if i % 2 else 1.0)
		place(out, render_note("snare", 0, 0.1, int(rng.integers(4))), max(0.0, tt), a)
	return finish_sfx(room(out, 0.7, 0.18), loud=-15)


def sfx_splash():
	rng = _rng("splash")
	out = np.zeros(nlen(1.2))
	n = nlen(0.9)
	t = _t(n)
	y = bq_sweep(noise(n, rng), "lp", 600 + 5000 * np.exp(-t / 0.12), 0.9) * np.minimum(1, t / 0.006) * np.exp(-t / 0.28)
	place(out, y, 0.0, 1.0)
	place(out, chirp_sine(160, 80, 0.12, 0.05, nlen(0.3)), 0.0, 0.5)
	bubbles(out, rng, 18, 0.05, 0.9, 500, 1800, 0.3)
	bubbles(out, rng, 8, 0.3, 1.0, 1800, 3200, 0.12)
	return finish_sfx(room(out, 0.5, 0.15), loud=-14)


def sfx_door():
	rng = _rng("door")
	out = np.zeros(nlen(0.9))
	n = nlen(0.44)
	t = _t(n)
	x = noise(n, rng)
	slide = bq(x, "bp", 700, 0.8) + 0.4 * bq(x, "bp", 2200, 1.5)
	am = 0.55 + 0.45 * np.abs(lp1(noise(n, rng), 30)) * 6
	env = np.minimum(1, t / 0.05) * np.clip((0.44 - t) / 0.06, 0, 1) * (0.7 + 0.3 * t / 0.44)
	place(out, slide * np.clip(am, 0, 1.6) * env, 0.0, 0.6)
	m = nlen(0.3)
	tt = _t(m)
	clack = _wood(m, rng, ((420, 0.8, 0.05), (980, 0.5, 0.03), (2100, 0.3, 0.015)), imp=0.5)
	clack += 0.5 * np.sin(TAU * 120 * tt) * np.exp(-tt / 0.04)
	place(out, clack, 0.42, 1.0)
	return finish_sfx(room(out, 0.5, 0.15), loud=-16)


def sfx_poof():
	rng = _rng("poof")
	out = np.zeros(nlen(2.4))
	n = nlen(0.8)
	t = _t(n)
	burst = bq_sweep(noise(n, rng), "lp", 400 + 2600 * np.exp(-t / 0.12), 0.8) * np.minimum(1, t / 0.015) * np.exp(-t / 0.22)
	place(out, burst, 0.0, 1.0)
	place(out, chirp_sine(120, 60, 0.12, 0.05, nlen(0.3)), 0.0, 0.4)
	pings(out, rng, 16, 0.04, 0.65, 2500, 7000, 0.3, 0.05, 0.15, early=1.0)
	for i, f in enumerate((1046.5, 1174.7, 1318.5, 1568.0, 1760.0, 2093.0)):
		place(out, render_note("glock", f, 0.2), 0.05 + 0.04 * i, 0.22)
	return finish_sfx(room(tail_fade(out, 0.9, 1.8), 1.0, 0.3), loud=-14)


def sfx_firework():
	rng = _rng("firework")
	out = np.zeros(nlen(2.6))
	n = nlen(0.75)
	t = _t(n)
	fr = 900 * 2.8 ** (t / 0.75) * (1 + 0.01 * np.sin(TAU * 13 * t))
	wh = np.sin(TAU * np.cumsum(fr) / SR) + 0.3 * bq(noise(n, rng), "bp", 3000, 1.0)
	place(out, wh * np.minimum(1, t / 0.1) * (0.4 + 0.6 * t / 0.75) * np.clip((0.75 - t) / 0.01, 0, 1), 0.0, 0.3)
	m = nlen(1.2)
	tt = _t(m)
	boom = lp1(noise(m, rng), 1500) * np.exp(-tt / 0.3) + np.sin(TAU * np.cumsum(35 + 35 * np.exp(-tt / 0.1)) / SR) * np.exp(-tt / 0.35)
	place(out, boom * np.minimum(1, tt / 0.002), 0.78, 1.0)
	for _ in range(130):
		u = rng.random() ** 1.5
		tt0 = 0.95 + 1.2 * u
		k = nlen(0.004)
		place(out, hp1(noise(k, rng), 2000) * np.exp(-_t(k) / 0.001), tt0, rng.uniform(0.2, 0.7) * (1 - 0.7 * u))
	pings(out, rng, 25, 0.9, 2.0, 3000, 8000, 0.12, 0.02, 0.08, early=1.3)
	return finish_sfx(room(out, 1.8, 0.3), loud=-13)


def sfx_boom():
	rng = _rng("boom")
	n = nlen(2.2)
	t = _t(n)
	sub = np.sin(TAU * np.cumsum(28 + 70 * np.exp(-t / 0.12)) / SR) * np.exp(-t / 0.7)
	nb = bq_sweep(noise(n, rng), "lp", 200 + 3000 * np.exp(-t / 0.05), 0.7) * np.exp(-t / 0.35)
	rum = lp1(lp1(noise(n, rng), 90), 90) * np.exp(-t / 0.9) * 8
	y = np.tanh(1.5 * (sub + 0.7 * nb + 0.5 * rum)) * np.minimum(1, t / 0.002)
	return finish_sfx(room(y, 1.2, 0.2), loud=-11)


def sfx_cheer():
	rng = _rng("cheer")
	dur = 2.8
	n = nlen(dur)
	t = _t(n)
	out = np.zeros(n)
	kernels = []
	for _ in range(6):
		k = nlen(0.012)
		kernels.append(bq(noise(k, rng), "bp", rng.uniform(900, 2600), 1.0) * np.exp(-_t(k) / 0.003))
	dens = lambda x: min(1.0, x / 0.2) * (1.0 if x < 1.4 else max(0.0, 1 - (x - 1.4) / 1.4))
	for _ in range(1100):
		tt = rng.uniform(0, dur)
		if rng.random() > dens(tt):
			continue
		place(out, kernels[int(rng.integers(6))], tt, rng.uniform(0.3, 1.0))
	app = out * 0.8
	vo = np.zeros(n)
	for i in range(14):
		on = rng.uniform(0, 0.3)
		vd = rng.uniform(0.9, 1.8)
		f0 = rng.uniform(170, 330) if i % 3 else rng.uniform(300, 520)
		m = nlen(vd)
		tt = _t(m)
		up = rng.uniform(3, 7)
		contour = np.where(tt < vd * 0.3, up * tt / (vd * 0.3), up - (up + 2) * (tt - vd * 0.3) / (vd * 0.7))
		vib = 1 + 0.01 * np.sin(TAU * rng.uniform(5, 6.5) * tt)
		src = osc_saw(f0 * 2 ** (contour / 12) * vib, m, rng.random())
		v = bq(src, "bp", 750, 5) + 0.6 * bq(src, "bp", 1150, 6) + 0.3 * bq(src, "bp", 2600, 8)
		v *= np.minimum(1, tt / 0.08) * np.clip((vd - tt) / 0.3, 0, 1)
		place(vo, v, on, rng.uniform(0.5, 1.0))
	wm = nlen(0.9)
	tw = _t(wm)
	wf = 2200 + 700 * np.sin(np.pi * tw / 0.9)
	whistle = np.sin(TAU * np.cumsum(wf) / SR) * np.sin(np.pi * tw / 0.9) ** 0.5
	y = app + 0.35 * lp1(vo, 5000) / max(1e-9, np.max(np.abs(vo))) * np.max(np.abs(app))
	place(y, whistle * 0.12 * np.max(np.abs(app)), 0.3)
	return finish_sfx(room(y, 0.9, 0.2), loud=-14)


def sfx_gasp():
	rng = _rng("gasp")
	out = np.zeros(nlen(0.9))
	for _ in range(7):
		on = rng.uniform(0, 0.07)
		d = rng.uniform(0.35, 0.55)
		m = nlen(d)
		tt = _t(m)
		x = noise(m, rng)
		f0 = rng.uniform(260, 480)
		voiced = osc_saw(f0 * 2 ** (4 * tt / d / 12), m, rng.random()) * 0.25
		src = x + voiced
		v = bq(src, "bp", 900, 3) + 0.7 * bq(src, "bp", 1500, 4) + 0.4 * bq(src, "bp", 2600, 5)
		v *= np.minimum(1, tt / 0.05) * np.exp(-np.maximum(0, tt - 0.1) / 0.15) * np.clip((d - tt) / 0.12, 0, 1)
		place(out, v, on, rng.uniform(0.6, 1.0))
	return finish_sfx(room(out, 0.6, 0.15), loud=-15)


def sfx_sizzle():
	rng = _rng("sizzle")
	dur = 1.6
	n = nlen(dur)
	t = _t(n)
	hiss = hp1(noise(n, rng), 3000) * np.clip(0.75 + 0.5 * lp1(noise(n, rng), 6) * 8, 0.3, 1.2)
	imp = np.zeros(n)
	cnt = rng.poisson(60 * dur)
	pos = rng.integers(0, n, cnt)
	imp[pos] = rng.exponential(1.0, cnt) * rng.choice([-1, 1], cnt)
	k = nlen(0.002)
	crack = hp1(np.convolve(imp, np.exp(-_t(k) / 0.0004))[:n], 1500)
	y = 0.45 * hiss + 0.6 * crack
	env = np.minimum(1, t / 0.15) * np.clip((dur - t) / 0.4, 0, 1)
	return finish_sfx(y * env, loud=-17)


def sfx_static():
	rng = _rng("static")
	dur = 1.2
	n = nlen(dur)
	t = _t(n)
	x = bq(bq(noise(n, rng), "hp", 300, 0.7), "lp", 8000, 0.7)
	steps = np.repeat(rng.uniform(0.55, 1.0, n // 640 + 1), 640)[:n]
	hum = 0.12 * np.sin(TAU * 60 * t) + 0.06 * np.sin(TAU * 180 * t)
	env = np.minimum(1, t / 0.01) * np.clip((dur - t) / 0.2, 0, 1)
	return finish_sfx((x * steps + hum) * env, loud=-18)


def sfx_correct():
	rng = _rng("correct")
	out = np.zeros(nlen(3.4))
	place(out, tone_bell(1568.0, 0.9, 0.3, ratio=3.0, idx=1.5), 0.0, 0.7)
	place(out, tone_bell(2093.0, 1.0, 0.45, ratio=3.0, idx=1.5), 0.06, 1.0)
	pings(out, rng, 7, 0.05, 0.4, 3500, 7500, 0.14, 0.02, 0.05, early=1.0)
	return finish_sfx(room(tail_fade(out, 0.7, 1.5), 0.9, 0.22), loud=-14)


SFX = {
	"blip": sfx_blip, "select": sfx_select, "confirm": sfx_confirm, "cancel": sfx_cancel, "clue": sfx_clue,
	"chime": sfx_chime, "body_found": sfx_body_found, "whoosh": sfx_whoosh, "shout": sfx_shout, "shoot": sfx_shoot,
	"break": sfx_break, "wrong": sfx_wrong, "pop": sfx_pop, "tick": sfx_tick, "heartbeat": sfx_heartbeat,
	"gavel": sfx_gavel, "slot": sfx_slot, "drumroll": sfx_drumroll, "splash": sfx_splash, "door": sfx_door,
	"poof": sfx_poof, "firework": sfx_firework, "boom": sfx_boom, "cheer": sfx_cheer, "gasp": sfx_gasp,
	"sizzle": sfx_sizzle, "static": sfx_static, "correct": sfx_correct,
}


# =====================================================================================  I/O + analysis
def write_wav(path, y, seed=0):
	rng = np.random.default_rng(seed)
	d = (rng.random(len(y)) - rng.random(len(y))) / 32768.0       # TPDF dither (+-1 LSB)
	q = np.clip(np.round((y + d) * 32767.0), -32768, 32767).astype("<i2")
	os.makedirs(os.path.dirname(path), exist_ok=True)
	with wave.open(path, "wb") as w:
		w.setnchannels(1)
		w.setsampwidth(2)
		w.setframerate(SR)
		w.writeframes(q.tobytes())


def read_wav(path):
	with wave.open(path, "rb") as w:
		assert w.getsampwidth() == 2, path
		ch, sr, n = w.getnchannels(), w.getframerate(), w.getnframes()
		data = np.frombuffer(w.readframes(n), dtype="<i2").astype(float) / 32768.0
	if ch > 1:
		data = data.reshape(-1, ch).mean(axis=1)
	return data, sr, ch


def analyze(path, is_music):
	x, sr, ch = read_wav(path)
	q = np.round(x * 32768).astype(int)
	info = {
		"id": os.path.splitext(os.path.basename(path))[0], "dur": len(x) / sr, "sr": sr, "ch": ch,
		"peak": db(np.max(np.abs(x))), "rms": db(rms(x)), "dc": float(np.mean(x)), "loud": st_loud(x),
		"kb": os.path.getsize(path) / 1024.0, "clip": int(np.sum(np.abs(q) >= 32767)),
	}
	if is_music:
		dif = np.abs(np.diff(q))
		p999 = float(np.percentile(dif, 99.9))
		seam = abs(int(q[0]) - int(q[-1]))
		# energy continuity across the seam (50 ms each side) vs typical neighbouring windows
		w = nlen(0.05)
		e_end, e_start = rms(x[-w:]), rms(x[:w])
		info.update({"seam": seam, "p999": p999, "seam_ok": seam <= max(p999, 64),
			"seam_db": db(e_start) - db(e_end), "frames": len(x)})
	return info


def print_table(results):
	music = [r for r in results if "seam" in r]
	sfx = [r for r in results if "seam" not in r]
	tot = sum(r["kb"] for r in results)
	if music:
		print("\nMUSIC  (16-bit PCM mono 32 kHz; seam = |first-last| sample step vs p99.9 of all steps)")
		print("%-13s %6s %7s %7s %7s %8s %6s %8s %8s %8s" % ("id", "dur s", "peak", "rms", "loud", "dc", "clip", "seam", "p99.9", "seam dE"))
		for r in music:
			print("%-13s %6.1f %7.2f %7.2f %7.2f %8.5f %6d %5d %-2s %8.0f %7.1fdB" % (
				r["id"], r["dur"], r["peak"], r["rms"], r["loud"], r["dc"], r["clip"], r["seam"],
				"ok" if r["seam_ok"] else "!!", r["p999"], r["seam_db"]))
	if sfx:
		print("\nSFX  (loud = max 100 ms K-weighted RMS)")
		print("%-11s %6s %7s %7s %7s %8s %6s" % ("id", "dur s", "peak", "rms", "loud", "dc", "clip"))
		for r in sfx:
			print("%-11s %6.3f %7.2f %7.2f %7.2f %8.5f %6d" % (r["id"], r["dur"], r["peak"], r["rms"], r["loud"], r["dc"], r["clip"]))
	print("\nTOTAL: %d files, %.2f MB (%.1f MiB)" % (len(results), tot * 1024 / 1e6, tot / 1024.0))


def job(kind, name, stems=False):
	t0 = time.time()
	_CACHE.clear()
	if kind == "music":
		song = SONGS[name]()
		y, gr = song.render(stems=stems)
		path = os.path.join(MUSIC_DIR, name + ".wav")
		write_wav(path, y, seed=zlib.crc32(name.encode()))
		info = analyze(path, True)
		info["gr"] = gr
	else:
		y = SFX[name]()
		path = os.path.join(SFX_DIR, name + ".wav")
		write_wav(path, y, seed=zlib.crc32(name.encode()))
		info = analyze(path, False)
		info["gr"] = _LAST_OVER
	info["secs"] = time.time() - t0
	_CACHE.clear()
	return info


def main():
	ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
	ap.add_argument("ids", nargs="*", help="music/sfx ids to render (default: all)")
	ap.add_argument("--analyze", action="store_true", help="only analyze existing files")
	ap.add_argument("--stems", action="store_true", help="print per-part levels for the rendered songs")
	ap.add_argument("-j", "--jobs", type=int, default=min(6, os.cpu_count() or 1))
	a = ap.parse_args()
	ids = a.ids or (list(SONGS) + list(SFX))
	for i in ids:
		if i not in SONGS and i not in SFX:
			sys.exit("unknown id %r. music: %s\nsfx: %s" % (i, ", ".join(SONGS), ", ".join(SFX)))
	if a.analyze:
		res = []
		for i in ids:
			kind = "music" if i in SONGS else "sfx"
			p = os.path.join(MUSIC_DIR if kind == "music" else SFX_DIR, i + ".wav")
			if os.path.exists(p):
				res.append(analyze(p, kind == "music"))
		print_table(res)
		return
	jobs = [("music" if i in SONGS else "sfx", i) for i in ids]
	jobs.sort(key=lambda j: 0 if j[0] == "music" else 1)
	t0 = time.time()
	res = []
	if a.jobs > 1 and len(jobs) > 1 and not a.stems:
		from concurrent.futures import ProcessPoolExecutor
		with ProcessPoolExecutor(max_workers=a.jobs) as ex:
			futs = [ex.submit(job, k, n) for k, n in jobs]
			for f in futs:
				r = f.result()
				print("  rendered %-13s %5.1fs%s" % (r["id"], r["secs"], ("  (peaks %+.1f dB over ceiling before limiter)" % r["gr"]) if "gr" in r else ""))
				res.append(r)
	else:
		for k, n in jobs:
			r = job(k, n, stems=a.stems)
			print("  rendered %-13s %5.1fs%s" % (r["id"], r["secs"], ("  (peaks %+.1f dB over ceiling before limiter)" % r["gr"]) if "gr" in r else ""))
			res.append(r)
	print_table(res)
	if not a.ids:
		allf = [os.path.join(MUSIC_DIR, f) for f in os.listdir(MUSIC_DIR) if f.endswith(".wav")]
		allf += [os.path.join(SFX_DIR, f) for f in os.listdir(SFX_DIR) if f.endswith(".wav")]
		print("audio folder total: %.2f MB  (%.1fs)" % (sum(os.path.getsize(p) for p in allf) / 1e6, time.time() - t0))


if __name__ == "__main__":
	main()
