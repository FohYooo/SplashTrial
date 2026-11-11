#!/usr/bin/env python3
"""SPLASH TRIAL - sound for the data-driven animated story scenes (scripts/data/anim_scenes.gd).

Writes (16-bit PCM, 44.1 kHz, mono):
  audio/music/an_jingle.wav   the shopping channel's bright, slightly seasick lounge loop (played off a worn tape)
  audio/sfx/an_kaching.wav    cash register drawer and bell
  audio/sfx/an_tvoff.wav      an old television switching off
  audio/sfx/an_flutter.wav    a cloud of bats taking off: leathery wingbeats, thick then thinning (Case 3, the cellar)
  audio/sfx/an_squeak.wav     one bat's shriek, high and chirping

Pure standard library, fully synthesized and deterministic (fixed seeds). Original composition.

    python3 tools/gen_anim_audio.py [names...]     (e.g. an_flutter an_squeak; no names writes them all)
"""
import math
import os
import random
import struct
import wave

SR = 44100
TAU = math.tau
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def write(path, buf, peak=0.82):
	top = max(abs(v) for v in buf) or 1.0
	data = b"".join(struct.pack("<h", int(max(-1.0, min(1.0, v / top * peak)) * 32767)) for v in buf)
	with wave.open(path, "wb") as f:
		f.setnchannels(1)
		f.setsampwidth(2)
		f.setframerate(SR)
		f.writeframes(data)
	print("%-28s %5.1f s" % (os.path.relpath(path, ROOT), len(buf) / SR))


def midi(n):
	return 440.0 * 2.0 ** ((n - 69) / 12.0)


def add_tone(buf, start, dur, freq, vol, kind, loop_len):
	"""Mixes one note in, wrapping around the end so the loop is seamless."""
	n = int(dur * SR)
	s0 = int(start * SR)
	ph = 0.0
	for i in range(n):
		t = i / SR
		k = i / n
		ph += TAU * freq / SR
		if kind == "keys":      # soft two-operator electric piano
			env = math.exp(-t * 3.4) * min(1.0, t * 200.0) * min(1.0, (1.0 - k) * 40.0)
			v = math.sin(ph + 1.7 * math.exp(-t * 7.0) * math.sin(ph * 14.0) * 0.18 + 0.9 * math.exp(-t * 5.0) * math.sin(ph * 2.0))
		elif kind == "bass":
			env = math.exp(-t * 2.2) * min(1.0, t * 300.0) * min(1.0, (1.0 - k) * 30.0)
			v = math.sin(ph) + 0.28 * math.sin(ph * 2.0)
		elif kind == "lead":    # reedy little organ with vibrato
			env = min(1.0, t * 26.0) * min(1.0, (1.0 - k) * 16.0)
			vib = 0.0032 * math.sin(TAU * 5.6 * t)
			v = math.sin(ph * (1.0 + vib)) + 0.42 * math.sin(ph * 2.0 * (1.0 + vib)) + 0.2 * math.sin(ph * 3.0)
		else:
			env = 0.0
			v = 0.0
		buf[(s0 + i) % loop_len] += v * env * vol


def add_noise(buf, start, dur, vol, rng, loop_len, hp=True):
	n = int(dur * SR)
	s0 = int(start * SR)
	prev = 0.0
	for i in range(n):
		w = rng.uniform(-1.0, 1.0)
		v = w - prev if hp else w
		prev = w
		buf[(s0 + i) % loop_len] += v * math.exp(-i / n * 5.0) * vol


def wow(buf, depth=0.0026, loop_seconds=None):
	"""Tape wow and flutter: resample the loop along a slowly wandering clock (whole cycles, so it still loops)."""
	n = len(buf)
	out = [0.0] * n
	wow_c = max(1, round(loop_seconds * 0.55))
	flut_c = max(1, round(loop_seconds * 6.1))
	for i in range(n):
		x = i / n
		off = (math.sin(TAU * wow_c * x) * depth + math.sin(TAU * flut_c * x) * depth * 0.22) * SR * 2.0
		p = (i + off) % n
		a = int(p)
		f = p - a
		out[i] = buf[a] * (1.0 - f) + buf[(a + 1) % n] * f
	return out


def jingle():
	bpm = 116.0
	beat = 60.0 / bpm
	bars = 8
	secs = bars * 4 * beat
	n = int(secs * SR)
	buf = [0.0] * n
	rng = random.Random(9021)
	# Fmaj7 Dm7 Gm7 C7 / Am7 D7 Gm7 C7
	chords = [
		[65, 69, 72, 76], [62, 65, 69, 72], [67, 70, 74, 77], [60, 64, 67, 70],
		[69, 72, 76, 79], [62, 66, 69, 72], [67, 70, 74, 77], [60, 64, 67, 70],
	]
	roots = [41, 38, 43, 36, 45, 38, 43, 36]
	for bar, chord in enumerate(chords):
		t0 = bar * 4 * beat
		# bossa-ish stabs
		for hit in (0.0, 1.5, 2.5, 3.5):
			for m, note in enumerate(chord):
				add_tone(buf, t0 + hit * beat + m * 0.004, beat * 1.1, midi(note), 0.09, "keys", n)
		r = roots[bar]
		for hit, off in ((0.0, 0), (1.5, 7), (2.0, 12), (3.0, 7), (3.5, 10)):
			add_tone(buf, t0 + hit * beat, beat * 0.85, midi(r + off), 0.24, "bass", n)
		for s in range(8):
			add_noise(buf, t0 + s * 0.5 * beat, 0.05, 0.045 if s % 2 else 0.075, rng, n)
	# a chirpy tune, a little too pleased with itself
	tune = [
		(0, 76, 1.5), (1.5, 77, 0.5), (2, 81, 1), (3, 79, 1), (4, 77, 1.5), (5.5, 74, 0.5), (6, 72, 2),
		(8, 74, 1.5), (9.5, 76, 0.5), (10, 79, 1), (11, 77, 1), (12, 76, 1.5), (13.5, 72, 0.5), (14, 70, 2),
		(16, 76, 1), (17, 79, 1), (18, 84, 1.5), (19.5, 83, 0.5), (20, 81, 2), (22, 78, 2),
		(24, 79, 1), (25, 77, 1), (26, 74, 1), (27, 70, 1), (28, 72, 3),
	]
	for b, note, length in tune:
		add_tone(buf, b * beat, length * beat * 0.95, midi(note), 0.13, "lead", n)
	return wow(buf, loop_seconds=n / SR)


def kaching():
	rng = random.Random(311)
	n = int(0.95 * SR)
	buf = [0.0] * n
	# drawer rattle
	for i in range(int(0.14 * SR)):
		buf[i] += rng.uniform(-1, 1) * math.exp(-i / SR * 24.0) * 0.6
	# two bright bells
	for start, base in ((0.09, 2093.0), (0.2, 2637.0)):
		s0 = int(start * SR)
		for i in range(n - s0):
			t = i / SR
			env = math.exp(-t * 5.0) * min(1.0, t * 900.0)
			v = math.sin(TAU * base * t) + 0.55 * math.sin(TAU * base * 2.76 * t) * math.exp(-t * 9.0) + 0.3 * math.sin(TAU * base * 5.4 * t) * math.exp(-t * 16.0)
			buf[s0 + i] += v * env * 0.45
	return buf


def tvoff():
	rng = random.Random(512)
	n = int(0.75 * SR)
	buf = [0.0] * n
	ph = 0.0
	for i in range(n):
		t = i / SR
		f = 15700.0 * math.exp(-t * 7.0) + 90.0
		ph += TAU * f / SR
		env = math.exp(-t * 4.2)
		buf[i] = math.sin(ph) * 0.34 * env
		if t < 0.05:
			buf[i] += rng.uniform(-1, 1) * (1.0 - t / 0.05) * 0.8
		buf[i] += math.sin(TAU * 58.0 * t) * math.exp(-t * 16.0) * 0.5
	return buf


def flutter():
	"""Many wings at once: each beat is a short burst of low-passed noise, at its own rate, fading as they go."""
	rng = random.Random(733)
	n = int(2.4 * SR)
	buf = [0.0] * n
	for b in range(26):
		rate = rng.uniform(9.0, 15.0)
		t0 = rng.uniform(0.0, 0.5)
		life = rng.uniform(1.0, 1.9)
		vol = rng.uniform(0.35, 0.8)
		t = t0
		while t < t0 + life and t < 2.3:
			s0 = int(t * SR)
			ln = int(0.035 * SR)
			lp = 0.0
			fade = 1.0 - (t - t0) / life
			for i in range(ln):
				if s0 + i >= n:
					break
				lp += (rng.uniform(-1, 1) - lp) * 0.18
				env = math.sin(math.pi * i / ln)
				buf[s0 + i] += lp * env * vol * fade
			t += 1.0 / rate + rng.uniform(-0.006, 0.006)
	return buf


def squeak():
	"""A bat's shriek: three fast chirps sweeping down from very high."""
	n = int(0.5 * SR)
	buf = [0.0] * n
	ph = 0.0
	for k, (start, f0, f1) in enumerate(((0.0, 7400.0, 4200.0), (0.12, 7800.0, 4600.0), (0.25, 8200.0, 3600.0))):
		s0 = int(start * SR)
		ln = int(0.09 * SR)
		for i in range(ln):
			x = i / ln
			f = f0 + (f1 - f0) * x
			ph += TAU * f / SR
			env = math.sin(math.pi * x) ** 0.6
			buf[s0 + i] += (math.sin(ph) + 0.3 * math.sin(ph * 2.01)) * env * 0.6
	return buf


SOUNDS = {
	"an_jingle": (("audio", "music"), jingle, 0.66),
	"an_kaching": (("audio", "sfx"), kaching, 0.8),
	"an_tvoff": (("audio", "sfx"), tvoff, 0.7),
	"an_flutter": (("audio", "sfx"), flutter, 0.75),
	"an_squeak": (("audio", "sfx"), squeak, 0.6),
}


def main():
	import sys
	only = set(sys.argv[1:])
	for name, (folder, fn, peak) in SOUNDS.items():
		if only and name not in only:
			continue
		write(os.path.join(ROOT, *folder, name + ".wav"), fn(), peak=peak)


if __name__ == "__main__":
	main()
