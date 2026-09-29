#!/usr/bin/env python3
"""SICHelper short - muzica si efectele sonore, generate de la zero (fara sample-uri straine).

Citeste out/cues.json (momentele din animatie, exportate de render.cjs --cues) si scrie out/audio.wav:
o piesa electronica de 60 s la 120 BPM, in La minor, cu sectiunile aliniate pe scene,
plus efectele sonore puse exact pe actiunile din video.
"""
import json
import os
import sys

import numpy as np
from scipy import signal
from scipy.io import wavfile

SR = 48000
DUR = 60.0
N = int(SR * DUR)
BPM = 120
BEAT = 60 / BPM
BAR = BEAT * 4
HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, 'out')
rng = np.random.default_rng(7)


# ------------------------------------------------------------------ utilitare
def mtof(m):
    return 440.0 * 2 ** ((m - 69) / 12)


def tt(dur):
    return np.arange(int(dur * SR)) / SR


def env_exp(dur, k):
    return np.exp(-tt(dur) * k)


def adsr(dur, a=0.01, d=0.1, s=0.7, r=0.1):
    n = int(dur * SR)
    e = np.full(n, s, dtype=np.float64)
    na, nd, nr = int(a * SR), int(d * SR), int(r * SR)
    na = min(na, n); e[:na] = np.linspace(0, 1, na, endpoint=False)
    nd = min(nd, n - na); e[na:na + nd] = np.linspace(1, s, nd, endpoint=False)
    if nr > 0 and nr < n:
        e[n - nr:] *= np.linspace(1, 0, nr)
    return e


def osc(freq, dur, kind='sine', phase=0.0):
    n = int(dur * SR)
    f = np.broadcast_to(np.asarray(freq, dtype=np.float64), (n,)) if np.ndim(freq) else np.full(n, float(freq))
    ph = phase + np.cumsum(f) / SR
    if kind == 'sine':
        return np.sin(2 * np.pi * ph)
    if kind == 'saw':
        return 2 * (ph % 1.0) - 1
    if kind == 'square':
        return np.sign(np.sin(2 * np.pi * ph))
    if kind == 'tri':
        return 2 * np.abs(2 * (ph % 1.0) - 1) - 1
    raise ValueError(kind)


def noise(dur):
    return rng.standard_normal(int(dur * SR))


def filt(x, kind, f, order=2):
    nyq = SR / 2
    if kind == 'bp':
        sos = signal.butter(order, [max(20, f[0]) / nyq, min(f[1], nyq * 0.95) / nyq], btype='band', output='sos')
    else:
        sos = signal.butter(order, min(max(f, 20), nyq * 0.95) / nyq, btype=kind, output='sos')
    return signal.sosfilt(sos, x)


def sweep(x, kind, f_start, f_end, order=2, block=512, bw=None):
    """filtru cu frecventa care se schimba in timp (pe blocuri, starea se pastreaza)"""
    out = np.zeros_like(x)
    nb = int(np.ceil(len(x) / block))
    zi = None
    for b in range(nb):
        fr = f_start * (f_end / f_start) ** (b / max(1, nb - 1))
        nyq = SR / 2
        if kind == 'bp':
            lo, hi = fr / (bw or 1.6), fr * (bw or 1.6)
            sos = signal.butter(order, [max(20, lo) / nyq, min(hi, nyq * 0.95) / nyq], btype='band', output='sos')
        else:
            sos = signal.butter(order, min(max(fr, 20), nyq * 0.95) / nyq, btype=kind, output='sos')
        if zi is None:
            zi = np.zeros((sos.shape[0], 2))
        seg_ = x[b * block:(b + 1) * block]
        y, zi = signal.sosfilt(sos, seg_, zi=zi)
        out[b * block:(b + 1) * block] = y
    return out


def pan(x, p):
    """p: -1 stanga .. 1 dreapta (sau un vector cu aceeasi lungime)"""
    p = np.clip(p, -1, 1)
    a = (p + 1) * np.pi / 4
    return np.stack([x * np.cos(a), x * np.sin(a)], axis=1)


def add(buf, t0, x, gain=1.0):
    if x.ndim == 1:
        x = np.stack([x, x], axis=1)
    i = int(round(t0 * SR))
    if i < 0:
        x = x[-i:]
        i = 0
    j = min(len(buf), i + len(x))
    if j > i:
        buf[i:j] += x[:j - i] * gain


def stereo(n):
    return np.zeros((n, 2))


def make_ir(dur=2.2, damp=4000):
    n = int(dur * SR)
    e = np.exp(-tt(dur) * 3.2)
    l = filt(rng.standard_normal(n) * e, 'low', damp)
    r = filt(rng.standard_normal(n) * e, 'low', damp)
    ir = np.stack([l, r], axis=1)
    return ir / np.sqrt(np.sum(ir ** 2))


IR = make_ir()
IR_SHORT = make_ir(0.8, 6000)


def reverb(x, ir=IR, wet=0.3):
    if x.ndim == 1:
        x = np.stack([x, x], axis=1)
    wetsig = np.stack([signal.fftconvolve(x[:, 0], ir[:, 0])[:len(x)], signal.fftconvolve(x[:, 1], ir[:, 1])[:len(x)]], axis=1)
    return x * (1 - wet) + wetsig * wet * 3.0


def mixa(*arrs):
    n = max(len(a) for a in arrs)
    out = np.zeros(n)
    for a in arrs:
        out[:len(a)] += a
    return out


def pad_tail(x, sec):
    if x.ndim == 1:
        return np.concatenate([x, np.zeros(int(sec * SR))])
    return np.concatenate([x, np.zeros((int(sec * SR), x.shape[1]))])


# ------------------------------------------------------------------ instrumente
def kick(g=1.0, dur=0.5):
    t = tt(dur)
    f = 42 + 120 * np.exp(-t * 30)
    x = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * 6.5)
    click = filt(noise(dur), 'high', 2500) * np.exp(-t * 300) * 0.35
    return np.tanh((x + click) * 1.6) * g


def clap(g=1.0):
    d = 0.35
    n = noise(d)
    t = tt(d)
    e = np.exp(-t * 18) * 0.9
    for off in (0.0, 0.011, 0.022):
        e += np.where(t >= off, np.exp(-(t - off) * 180), 0) * 0.6
    return filt(n * e, 'bp', (900, 6000)) * g


def snare(g=1.0):
    d = 0.3
    t = tt(d)
    tone = np.sin(2 * np.pi * 190 * t) * np.exp(-t * 25) * 0.5
    nz = filt(noise(d), 'bp', (1500, 9000)) * np.exp(-t * 16)
    return (tone + nz) * g


def hat(g=1.0, open_=False):
    d = 0.35 if open_ else 0.06
    t = tt(d)
    x = filt(noise(d), 'high', 7500) * np.exp(-t * (9 if open_ else 70))
    return x * g


def crash(g=1.0, d=2.2):
    t = tt(d)
    x = filt(noise(d), 'high', 3500) * np.exp(-t * 2.2)
    ring_ = sum(np.sin(2 * np.pi * f * t) for f in (3150, 4420, 5870, 7310)) * 0.05 * np.exp(-t * 3)
    return (x + ring_) * g


def tom(f0=120, g=1.0):
    d = 0.4
    t = tt(d)
    f = f0 * (0.7 + 0.3 * np.exp(-t * 12))
    return np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * 9) * g


def pluck(m, dur, g=1.0, bright=2500, kind='saw'):
    f = mtof(m)
    t = tt(dur)
    x = osc(f, dur, kind) * 0.6 + osc(f * 1.005, dur, kind) * 0.4
    x = sweep(x * np.exp(-t * 7), 'low', bright, 400, block=256)
    return x * g


def bass_note(m, dur, g=1.0, cutoff=700):
    f = mtof(m)
    t = tt(dur)
    x = osc(f, dur, 'saw') * 0.7 + osc(f / 2, dur, 'square') * 0.35
    x = sweep(x, 'low', cutoff * 2.2, cutoff * 0.6, block=256) * adsr(dur, 0.005, 0.08, 0.7, 0.03)
    return np.tanh(x * 1.4) * g


def pad_chord(ms, dur, g=1.0, cut=(900, 900)):
    x = np.zeros(int(dur * SR))
    for m in ms:
        f = mtof(m)
        for dt in (-0.12, 0.0, 0.11):
            x += osc(f * 2 ** (dt / 12), dur, 'saw', phase=rng.random())
    x = sweep(x / (len(ms) * 3), 'low', cut[0], cut[1], block=1024)
    return x * adsr(dur, 0.25, 0.3, 0.85, 0.35) * g


def lead_note(m, dur, g=1.0):
    f = mtof(m)
    t = tt(dur)
    vib = 1 + 0.004 * np.sin(2 * np.pi * 5.5 * t) * np.clip(t * 4 - 0.4, 0, 1)
    x = osc(f * vib, dur, 'square') * 0.5 + osc(f * 1.003 * vib, dur, 'saw') * 0.5
    x = filt(x, 'low', 3200) * adsr(dur, 0.008, 0.12, 0.6, 0.06)
    return x * g


def bell(m, dur=1.2, g=1.0):
    f = mtof(m)
    t = tt(dur)
    x = (np.sin(2 * np.pi * f * t) + 0.45 * np.sin(2 * np.pi * f * 2.0 * t) * np.exp(-t * 3)
         + 0.25 * np.sin(2 * np.pi * f * 3.01 * t) * np.exp(-t * 6) + 0.15 * np.sin(2 * np.pi * f * 4.2 * t) * np.exp(-t * 9))
    return x * np.exp(-t * 3.2) * np.clip(t * 400, 0, 1) * g


# ------------------------------------------------------------------ muzica
AM, F_, C_, G_ = [57, 60, 64], [53, 57, 60], [55, 60, 64], [55, 59, 62]
DM, E_ = [57, 62, 65], [52, 56, 59]
BASS = {'Am': 45, 'F': 41, 'C': 48, 'G': 43, 'Dm': 38, 'E': 40}
CHORD = {'Am': AM, 'F': F_, 'C': C_, 'G': G_, 'Dm': DM, 'E': E_}
PROG = ['Am', 'F', 'C', 'G']


def chord_of_bar(b):
    if b in (19, 20, 21):
        return ['Dm', 'F', 'E'][b - 19]
    if b >= 29:
        return 'Am'
    return PROG[b % 4]


def section(b):
    t = b * BAR
    if t < 6: return 'intro'
    if t < 12: return 'groove'
    if t < 22: return 'full'
    if t < 32: return 'drive'
    if t < 38: return 'break'
    if t < 44: return 'tension'
    if t < 50: return 'groove2'
    if t < 58: return 'climax'
    return 'end'


MELODY = [(0, 76, 0.5), (0.75, 79, 0.25), (1, 81, 0.75), (2, 79, 0.5), (2.5, 76, 0.5), (3, 74, 1.0),
          (4, 72, 0.5), (4.5, 74, 0.5), (5, 76, 0.75), (6, 79, 0.5), (6.5, 76, 0.5), (7, 74, 0.5), (7.5, 72, 0.5)]


def build_music():
    drums, bassb, padb, arpb, leadb = stereo(N + SR * 3), stereo(N + SR * 3), stereo(N + SR * 3), stereo(N + SR * 3), stereo(N + SR * 3)
    kicks = []
    nbars = int(DUR / BAR)
    for b in range(nbars):
        t0 = b * BAR
        sec = section(b)
        ch = chord_of_bar(b)
        notes = CHORD[ch]
        # pad
        if sec in ('intro',):
            cut = (350 + 700 * (b / 3), 350 + 700 * ((b + 1) / 3))
            add(padb, t0, pan(pad_chord(notes, BAR + 0.3, 0.55, cut), 0), 1)
        elif sec == 'end':
            add(padb, t0, pan(pad_chord(notes + [69], 3.2, 0.7, (2400, 600)), 0), 1)
        else:
            cut = {'break': (1300, 1300), 'tension': (700 + 500 * (b - 19), 1200 + 500 * (b - 19)), 'climax': (2200, 2200)}.get(sec, (1600, 1600))
            add(padb, t0, pan(pad_chord(notes, BAR + 0.3, 0.5 if sec != 'climax' else 0.55, cut), 0), 1)
        # tobe
        for beat in range(4):
            tb = t0 + beat * BEAT
            if sec in ('groove', 'full', 'drive', 'groove2', 'climax'):
                add(drums, tb, kick(0.95), 1); kicks.append(tb)
            if sec == 'tension':
                add(drums, tb, kick(0.7 if b < 21 else 0.85), 1); kicks.append(tb)
            if sec in ('full', 'drive', 'groove2', 'climax', 'groove') and beat in (1, 3):
                add(drums, tb, pan(clap(0.55), 0.05), 1)
            if sec == 'break' and beat == 3:
                add(drums, tb, pan(clap(0.3), 0.1), 1)
            # hats
            if sec == 'intro' and b >= 1:
                add(drums, tb + BEAT / 2, pan(hat(0.18), 0.3), 1)
            if sec in ('groove', 'groove2'):
                add(drums, tb + BEAT / 2, pan(hat(0.3, True), 0.25), 1)
                add(drums, tb, pan(hat(0.16), -0.3), 1)
            if sec in ('full', 'drive', 'climax'):
                for s16 in range(4):
                    add(drums, tb + s16 * BEAT / 4, pan(hat(0.15 if s16 % 2 else 0.08), -0.25 + 0.5 * (s16 % 2)), 1)
                add(drums, tb + BEAT / 2, pan(hat(0.15, True), 0.3), 1)
            if sec == 'tension':
                add(drums, tb + BEAT / 2, pan(hat(0.2), 0.2), 1)
        # rulada de toba spre drop-uri
        if b in (2, 5, 10, 15, 24):
            for k in range(8):
                add(drums, t0 + 3 * BEAT + k * BEAT / 8, pan(snare(0.18 + k * 0.05), 0), 1)
        if b == 21:  # rulada care accelereaza pana la 44 s
            steps = np.concatenate([np.arange(0, 1, 1 / 4), 1 + np.arange(0, 1, 1 / 8), 2 + np.arange(0, 1, 1 / 16), 3 + np.arange(0, 1, 1 / 32)]) * BEAT
            for k, s in enumerate(steps):
                add(drums, t0 + s, pan(snare(0.12 + 0.5 * k / len(steps)), 0), 1)
        if sec == 'drive' and b in (12, 14):
            for k, f0 in enumerate((180, 150, 120, 95)):
                add(drums, t0 + 3 * BEAT + k * BEAT / 4, pan(tom(f0, 0.6), -0.4 + k * 0.25), 1)
        # bas
        root = BASS[ch]
        if sec in ('groove', 'groove2', 'full', 'climax'):
            for e8 in range(8):
                m = root + (12 if (sec in ('full', 'climax') and e8 % 2) else 0)
                add(bassb, t0 + e8 * BEAT / 2, bass_note(m, BEAT / 2 * 0.9, 0.5), 1)
        elif sec == 'drive':
            for s16 in range(16):
                if s16 % 4 == 0:
                    continue
                add(bassb, t0 + s16 * BEAT / 4, bass_note(root + (12 if s16 % 4 == 2 else 0), BEAT / 4 * 0.9, 0.45, 900), 1)
        elif sec == 'tension':
            for e8 in range(8):
                add(bassb, t0 + e8 * BEAT / 2, bass_note(root, BEAT / 2 * 0.85, 0.42, 500 + 200 * (b - 19)), 1)
        elif sec == 'intro' and b == 2:
            add(bassb, t0 + 2 * BEAT, bass_note(root, BEAT * 2, 0.3, 300), 1)
        # arpegiu
        arp_notes = [notes[0] + 12, notes[1] + 12, notes[2] + 12, notes[1] + 12]
        if sec in ('intro', 'break'):
            for e8 in range(8):
                m = arp_notes[e8 % 4]
                add(arpb, t0 + e8 * BEAT / 2, pan(pluck(m, 0.4, 0.22, 1200 if sec == 'intro' else 1800), -0.4 + 0.8 * (e8 % 2)), 1)
        elif sec in ('full', 'groove', 'groove2', 'climax', 'tension', 'drive'):
            bright = {'tension': 1000 + 1800 * (b - 19) / 2, 'drive': 2600}.get(sec, 3200)
            for s16 in range(16):
                m = arp_notes[s16 % 4] + (12 if (sec == 'climax' and s16 % 8 >= 4) else 0)
                if sec == 'drive' and s16 % 2:
                    continue
                add(arpb, t0 + s16 * BEAT / 4, pan(pluck(m, 0.25, 0.16, bright), -0.5 + (s16 % 4) / 3), 1)
        # melodia
        if sec in ('climax', 'drive') or (sec == 'full' and b >= 8):
            half = b % 2
            for (bo, m, d) in MELODY:
                if (bo >= 4) != bool(half):
                    continue
                ts = t0 + (bo - 4 * half) * BEAT
                add(leadb, ts, pan(lead_note(m + (0 if sec != 'drive' else -12), d * BEAT * 0.95, 0.2), 0.1), 1)
    # final: acordul lung si crash
    add(drums, 58.0, kick(1.2, 0.9), 1)
    add(drums, 58.0, pan(crash(0.5, 2.0), 0), 1)
    # crash-uri pe drop-uri
    for tdrop in (6.0, 12.0, 22.0, 44.0, 50.0):
        add(drums, tdrop, pan(crash(0.35), 0.2), 1)
    # riser de zgomot inainte de drop-uri
    for (a, b_) in ((4.5, 6.0), (10.5, 12.0), (20.5, 22.0), (48.5, 50.0), (56.2, 58.0)):
        d = b_ - a
        x = sweep(noise(d), 'bp', 400, 7000, bw=1.4) * np.linspace(0, 1, int(d * SR)) ** 2 * 0.25
        add(drums, a, pan(x, np.linspace(-0.5, 0.5, len(x))), 1)
    # sidechain de la kick pe bas / pad / arpegiu
    sc = np.ones(len(bassb))
    for k in kicks:
        i = int(k * SR)
        n = int(0.28 * SR)
        j = min(len(sc), i + n)
        sc[i:j] = np.minimum(sc[i:j], 1 - 0.6 * np.exp(-np.arange(j - i) / SR * 14))
    sc = sc[:, None]
    padb = reverb(padb * sc, wet=0.35)
    arpb = reverb(arpb * sc, wet=0.3)
    leadb = reverb(leadb, wet=0.25)
    bassb = np.stack([filt(bassb[:, 0], 'high', 35), filt(bassb[:, 1], 'high', 35)], axis=1) * sc
    drums = drums + reverb(drums, IR_SHORT, wet=1.0) * 0.08
    music = drums * 0.85 + bassb * 0.9 + padb * 0.55 + arpb * 0.6 + leadb * 0.7
    return music[:N]


# ------------------------------------------------------------------ efecte sonore
def sfx(name, c):
    g = c.get('g', 1.0)
    v = c.get('v', 0)
    d = c.get('d', 1.0)
    if name == 'key':
        t = tt(0.05)
        f = 1.0 + 0.08 * ((v * 37) % 7) / 7
        x = filt(noise(0.05), 'bp', (1800 * f, 6000)) * np.exp(-t * 180) * 0.7 + np.sin(2 * np.pi * 160 * f * t) * np.exp(-t * 90) * 0.5
        return pan(x * 0.5 * g, -0.2)
    if name == 'enter':
        t = tt(0.1)
        x = filt(noise(0.1), 'bp', (1200, 5000)) * np.exp(-t * 90) + np.sin(2 * np.pi * 120 * t) * np.exp(-t * 50) * 0.8
        return pan(x * 0.6 * g, -0.2)
    if name == 'keyBig':
        t = tt(0.25)
        x = np.sin(2 * np.pi * 90 * t) * np.exp(-t * 30) + filt(noise(0.25), 'bp', (1500, 5000)) * np.exp(-t * 60) * 0.8
        return reverb(pan(x * 0.8 * g, 0.2), IR_SHORT, 0.25)
    if name == 'chatopen':
        t = tt(0.06)
        return pan(np.sin(2 * np.pi * 1300 * t) * np.exp(-t * 80) * 0.25 * g, -0.3)
    if name in ('hit', 'hitSoft', 'impact'):
        big = name == 'impact'
        dd = 1.6 if big else 0.9
        t = tt(dd)
        boom = np.sin(2 * np.pi * np.cumsum(38 + 90 * np.exp(-t * 18)) / SR) * np.exp(-t * (2.5 if big else 5))
        crack = filt(noise(dd), 'bp', (800, 8000)) * np.exp(-t * 25)
        x = np.tanh((boom * 1.4 + crack * 0.6) * 1.2) * (0.9 if big else 0.6 if name == 'hit' else 0.4)
        return reverb(pan(pad_tail(x, 1.0), 0), wet=0.3) * g
    if name in ('whoosh', 'whooshUp', 'whooshBig'):
        dd = {'whoosh': 0.55, 'whooshUp': 0.9, 'whooshBig': 0.9}[name]
        n = noise(dd)
        if name == 'whooshUp':
            x = sweep(n, 'bp', 300, 5000, bw=1.5)
        else:
            half = int(len(n) * 0.55)
            x = np.concatenate([sweep(n[:half], 'bp', 400 if name == 'whoosh' else 200, 4000 if name == 'whoosh' else 2500, bw=1.5),
                                sweep(n[half:], 'bp', 4000 if name == 'whoosh' else 2500, 600 if name == 'whoosh' else 250, bw=1.5)])
        e = np.sin(np.linspace(0, np.pi, len(x))) ** 1.5
        return pan(x * e * (0.9 if name != 'whooshBig' else 1.2) * g, np.linspace(-0.7, 0.7, len(x)))
    if name == 'signal':
        dd = 1.1
        t = tt(dd)
        f = 400 * (4 ** (t / dd))
        x = np.sin(2 * np.pi * np.cumsum(f) / SR) * (0.6 + 0.4 * np.sin(2 * np.pi * 18 * t)) * np.sin(np.pi * t / dd)
        sp = sum(bell(m, dd, 0.12) for m in (88, 93, 96))
        return reverb(pan((x * 0.3 + sp) * g, np.linspace(0, 0.6, len(x))), wet=0.35)
    if name == 'notif':
        x = pad_tail(bell(88, 0.9, 0.35), 0.2)
        y = bell(93, 1.1, 0.4)
        add_ = np.zeros(len(y) + int(0.1 * SR)); add_[:len(x)] += x[:len(add_)] if len(x) <= len(add_) else x[:len(add_)]
        add_[int(0.1 * SR):] += y
        return reverb(pan(add_ * g, 0), wet=0.35)
    if name == 'send':
        t = tt(0.16)
        f = 600 * (2.6 ** (t / 0.16))
        x = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * 12) * 0.35 + filt(noise(0.16), 'high', 3000) * np.exp(-t * 30) * 0.2
        return reverb(pan(x * g, 0.3), IR_SHORT, 0.3)
    if name == 'blip':
        t = tt(0.1)
        return pan(np.sin(2 * np.pi * c.get('f', 1200) * t) * np.exp(-t * 35) * 0.3 * g, 0.4)
    if name == 'unlock':
        out = np.zeros(int(0.5 * SR))
        t = tt(0.07)
        b = osc(2200, 0.07, 'square') * 0.15 * np.exp(-t * 10)
        b = filt(b, 'low', 5000)
        for off in (0.0, 0.14):
            i = int(off * SR); out[i:i + len(b)] += b
        return pan(out * g, 0.5)
    if name == 'sms':
        out = np.zeros(int(1.2 * SR))
        t = tt(0.18)
        buzz = filt(osc(150, 0.18, 'square'), 'low', 600) * (0.5 + 0.5 * np.sin(2 * np.pi * 30 * t)) * 0.25
        for off in (0.0, 0.26):
            i = int(off * SR); out[i:i + len(buzz)] += buzz
        d1 = bell(84, 0.6, 0.25); d2 = bell(88, 0.6, 0.25)
        i = int(0.55 * SR); out[i:i + len(d1)] += d1[:len(out) - i]
        i = int(0.65 * SR); out[i:i + len(d2)] += d2[:len(out) - i]
        return reverb(pan(out * g, -0.3), IR_SHORT, 0.3)
    if name == 'typeBurst':
        out = np.zeros(int(0.35 * SR))
        for k in range(7):
            x = sfx('key', {'v': k})[:, 0] * 0.6
            i = int(k * 0.042 * SR); out[i:i + len(x)] += x[:len(out) - i]
        return pan(out * g, -0.35)
    if name == 'tick':
        t = tt(0.06)
        f = 2200 * 2 ** (v / 12 * 2)
        x = np.sin(2 * np.pi * f * t) * np.exp(-t * 70) * 0.3 + filt(noise(0.06), 'high', 4000) * np.exp(-t * 200) * 0.2
        return pan(x * g, -0.3 + 0.12 * v)
    if name in ('scan', 'scanStart'):
        dd = d if name == 'scan' else 0.6
        t = tt(dd)
        f = 500 * (5 ** (t / dd))
        x = np.sin(2 * np.pi * np.cumsum(f) / SR) * (0.5 + 0.5 * np.sign(np.sin(2 * np.pi * 28 * t))) * 0.14
        x += sweep(noise(dd), 'bp', 800, 6000, bw=1.3) * 0.12
        x *= np.sin(np.pi * t / dd) ** 0.5
        return pan(x * g, np.linspace(-0.6, 0.6, len(x)))
    if name == 'pop':
        t = tt(0.12)
        f = 300 * (3 ** (t / 0.07))
        x = np.sin(2 * np.pi * np.cumsum(np.minimum(f, 900)) / SR) * np.exp(-t * 30) * 0.4
        return reverb(pan(x * g, 0), IR_SHORT, 0.25)
    if name == 'fill':
        out = np.zeros(int(0.8 * SR))
        for k, m in enumerate((81, 84, 86, 88, 93)):
            x = bell(m, 0.3, 0.12)
            i = int(k * 0.12 * SR); out[i:i + len(x)] += x[:len(out) - i]
        return pan(out * g, 0.2)
    if name == 'check':
        out = np.zeros(int(0.8 * SR))
        a_, b_ = bell(91, 0.5, 0.25), bell(96, 0.6, 0.25)
        out[:len(a_)] += a_; i = int(0.08 * SR); out[i:i + len(b_)] += b_[:len(out) - i]
        return reverb(pan(out * g, 0), IR_SHORT, 0.3)
    if name == 'lock':
        out = np.zeros(int(1.0 * SR))
        t = tt(0.06)
        bp = filt(osc(1800, 0.06, 'square'), 'low', 4000) * 0.12
        for k in range(3):
            i = int(k * 0.09 * SR); out[i:i + len(bp)] += bp
        th = sfx('hitSoft', {})[:, 0]
        i = int(0.3 * SR); out[i:] += th[:len(out) - i] * 0.8
        return pan(out * g, 0)
    if name == 'engine':
        tl = tt(d)
        u = np.clip((tl + 22.1 - 22.4) / (31.2 - 22.4), 0, 1)
        speed = np.where(u < 0.5, 2 * u, 2 * (1 - u))
        f0 = 48 + 70 * speed + 4 * np.sin(2 * np.pi * 0.7 * tl)
        x = osc(f0, d, 'saw') * 0.5 + osc(f0 * 2.01, d, 'saw') * 0.25 + osc(f0 * 0.5, d, 'square') * 0.3
        x = filt(x, 'low', 700) + filt(noise(d), 'low', 300) * 0.3
        e = np.clip(tl / 0.4, 0, 1) * np.clip((d - tl) / 0.5, 0, 1) * (0.5 + 0.5 * speed)
        return pan(np.tanh(x * 1.5) * e * 0.28 * g, 0)
    if name == 'engineIn':
        tl = tt(d)
        f0 = 110 - 60 * (tl / d)
        x = osc(f0, d, 'saw') * 0.5 + osc(f0 * 2.01, d, 'saw') * 0.25
        x = filt(x, 'low', 800)
        e = np.clip(tl / 0.2, 0, 1) * np.clip((d - tl) / 0.4, 0, 1)
        return pan(np.tanh(x * 1.5) * e * 0.3 * g, np.linspace(-0.9, 0, len(x)))
    if name in ('skid', 'brake'):
        dd = 0.55 if name == 'skid' else 0.6
        t = tt(dd)
        f = 1750 * (1 + 0.03 * np.sin(2 * np.pi * 13 * t))
        x = np.sin(2 * np.pi * np.cumsum(f) / SR) * 0.12 + filt(noise(dd), 'bp', (1400, 3000)) * 0.2
        e = np.sin(np.pi * t / dd) ** 0.7
        return pan(x * e * g, 0.2 if name == 'skid' else -0.3)
    if name == 'ping':
        x = bell(86, 1.4, 0.3)
        return reverb(pan(x * g, 0.4), wet=0.45)
    if name == 'door':
        t = tt(0.35)
        x = filt(noise(0.35), 'low', 220) * np.exp(-t * 18) * 1.2 + filt(noise(0.35), 'bp', (2000, 6000)) * np.exp(-t * 120) * 0.3
        return pan(x * g, -0.3)
    if name == 'dialog':
        out = np.zeros(int(0.5 * SR))
        a_, b_ = bell(79, 0.3, 0.18), bell(84, 0.35, 0.18)
        out[:len(a_)] += a_; i = int(0.07 * SR); out[i:i + len(b_)] += b_[:len(out) - i]
        return pan(out * g, 0)
    if name == 'alert':
        out = np.zeros(int(0.4 * SR))
        base = 0 if v < 9 else -5
        for k, m in enumerate((76 + base, 72 + base)):
            t = tt(0.11)
            x = filt(osc(mtof(m), 0.11, 'square'), 'low', 2500) * np.exp(-t * 12) * 0.18
            i = int(k * 0.1 * SR); out[i:i + len(x)] += x
        return reverb(pan(out * g, -0.2 + 0.1 * (v % 5)), IR_SHORT, 0.3)
    if name == 'stamp':
        x = sfx('impact', {})[:, 0]
        t = tt(1.2)
        clang = sum(np.sin(2 * np.pi * f * t) for f in (420, 1130, 2270)) * np.exp(-t * 5) * 0.12
        x[:len(clang)] += clang
        return pan(x * 0.9 * g, 0)
    if name == 'riser':
        t = tt(d)
        f = 200 * (8 ** (t / d))
        x = np.sin(2 * np.pi * np.cumsum(f) / SR) * 0.12 + sweep(noise(d), 'bp', 300, 8000, bw=1.3) * 0.25
        return pan(x * (t / d) ** 2 * g, 0)
    if name == 'glitch':
        dd = 0.3
        t = tt(dd)
        x = osc(220 * (1 + 3 * (np.floor(t * 40) % 3)), dd, 'square') * 0.12
        x *= (np.floor(t * 60) % 2)
        x += filt(noise(dd), 'high', 2000) * (np.floor(t * 45) % 2) * 0.2
        return pan(np.round(x * 8) / 8 * g, 0)
    if name == 'click':
        t = tt(0.04)
        x = filt(noise(0.04), 'bp', (2500, 8000)) * np.exp(-t * 300) * 0.6 + np.sin(2 * np.pi * 1800 * t) * np.exp(-t * 200) * 0.2
        return pan(x * g, 0.1)
    if name == 'coins':
        out = np.zeros(int(0.7 * SR))
        for k, m in enumerate((96, 100, 103, 108)):
            x = bell(m, 0.35, 0.09)
            i = int(k * 0.05 * SR); out[i:i + len(x)] += x[:len(out) - i]
        return pan(out * g, 0.2)
    if name == 'shutter':
        out = np.zeros(int(0.3 * SR))
        t = tt(0.05)
        cl = filt(noise(0.05), 'bp', (1500, 7000)) * np.exp(-t * 160) * 0.7
        out[:len(cl)] += cl; i = int(0.07 * SR); out[i:i + len(cl)] += cl * 0.8
        return pan(out * g, 0)
    if name == 'sendCard':
        x = sfx('whoosh', {'g': 0.55})
        t = tt(0.06)
        fl = filt(noise(0.06), 'bp', (3000, 9000)) * np.exp(-t * 120) * 0.3
        x[:len(fl)] += fl[:, None]
        return x * g
    if name == 'success':
        m = (81, 84, 86, 88, 93)[v % 5]
        x = mixa(bell(m, 1.0, 0.32), bell(m + 12, 0.6, 0.1), pluck(m, 0.5, 0.12, 5000))
        return reverb(pan(x * g, -0.4 + 0.2 * v), wet=0.3)
    if name == 'finale':
        out = np.zeros(int(3.0 * SR))
        imp = sfx('impact', {})[:, 0]
        out[:len(imp)] += imp[:len(out)] * 0.8
        for k, m in enumerate((81, 84, 88, 93, 95, 100)):
            x = bell(m, 1.4, 0.16)
            i = int(k * 0.06 * SR); out[i:i + len(x)] += x[:len(out) - i]
        out += np.pad(crash(0.35, 2.4), (0, max(0, len(out) - int(2.4 * SR))))[:len(out)]
        return reverb(pan(out * g, 0), wet=0.3)
    print('sunet necunoscut:', name, file=sys.stderr)
    return np.zeros((1, 2))


# ------------------------------------------------------------------ mixajul
def main():
    cues = json.load(open(os.path.join(OUT, 'cues.json')))['cues']
    music = build_music()
    fx = stereo(N + SR * 4)
    for c in cues:
        x = sfx(c['s'], c)
        add(fx, c['t'], x, 1.0)
    fx = fx[:N]
    # muzica se da putin la o parte cand vin efectele (ca sa se auda clar)
    lvl = np.sqrt(np.maximum(filt(np.mean(fx ** 2, axis=1), 'low', 8), 0))
    duck = 1 - np.clip(lvl * 2.2, 0, 0.4)
    music = music * duck[:, None]
    mix = music * 0.8 + fx * 1.0
    # iesirea de la final
    fade = np.ones(N)
    nf = int(0.6 * SR)
    fade[-nf:] = np.linspace(1, 0, nf) ** 1.5
    fin = int(0.012 * SR)
    fade[:fin] = np.linspace(0, 1, fin)
    mix *= fade[:, None]
    mix = np.stack([filt(filt(mix[:, 0], 'high', 25), 'low', 15000), filt(filt(mix[:, 1], 'high', 25), 'low', 15000)], axis=1)
    # compresie simpla + saturatie usoara, apoi normalizare la -1 dBFS
    rms = np.sqrt(np.mean(mix ** 2))
    mix *= 0.2 / max(rms, 1e-9)
    mix = np.tanh(mix * 1.1) / np.tanh(1.1)
    mix *= 10 ** (-1 / 20) / np.max(np.abs(mix))
    print('rms dBFS: %.1f' % (20 * np.log10(np.sqrt(np.mean(mix ** 2)))))
    wavfile.write(os.path.join(OUT, 'audio.wav'), SR, (mix * 32767).astype(np.int16))
    print('scris:', os.path.join(OUT, 'audio.wav'))


if __name__ == '__main__':
    main()
