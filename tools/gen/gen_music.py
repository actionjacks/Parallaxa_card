#!/usr/bin/env python3
"""Procedural music generator for Parallaxa_card.

Renders the 4 mono music loops into assets/audio/music/ exactly per
docs/specs/spec_content.md section 3 ("Procedural music"):

    menu_drone.wav      32.000 s   1,024,000 samples
    combat_loop.wav     20.000 s     640,000 samples
    boss_loop.wav       24.000 s     768,000 samples
    heartbeat_loop.wav   4.000 s     128,000 samples

Format: WAV PCM 16-bit mono 32000 Hz, peak-normalized to 0.71 (-3 dBFS).
Seamless loop: each track is rendered 0.5 s LONGER than its loop length,
then the extra tail is equal-power crossfaded into the head
(out[i] = head[i]*sqrt(t) + tail[i]*sqrt(1-t)) and the track is cut to
exact length. Events whose onsets fall inside the extra 0.5 s window are
scheduled from the NEXT loop cycle, so the crossfaded head matches what
the loop restart actually plays.

Stdlib only (math, wave, array). Fully deterministic: no `random` module;
the only noise source is the LCG below with seed 1909.

Run from repo root:  python3 tools/gen/gen_music.py
"""

import math
import os
import sys
import wave
from array import array

SR = 32000                      # sample rate, Hz
XFADE_S = 0.5                   # loop-seam crossfade, seconds
XFADE_N = int(XFADE_S * SR)     # 16000 samples
PEAK = 0.71                     # peak normalization target (-3 dBFS)
OUT_DIR = os.path.join("assets", "audio", "music")

TWO_PI = 2.0 * math.pi

# ---------------------------------------------------------------------------
# Note frequency table from the spec (equal temperament, A4 = 440 Hz).
# Eb5 is not listed in the spec table; 622.25 is the ET value at the same
# precision (needed as "root+12" of the Eb chord in the combat arp).
# ---------------------------------------------------------------------------
D1 = 36.71
C2 = 65.41
CS2 = 69.30
D2 = 73.42
EB2 = 77.78
F2 = 87.31
G2 = 98.00
A2 = 110.00
BB2 = 116.54
C3 = 130.81
CS3 = 138.59
D3 = 146.83
EB3 = 155.56
E3 = 164.81
F3 = 174.61
FS3 = 185.00
G3 = 196.00
A3 = 220.00
BB3 = 233.08
C4 = 261.63
D4 = 293.66
EB4 = 311.13
F4 = 349.23
G4 = 392.00
AB4 = 415.30
A4 = 440.00
BB4 = 466.16
C5 = 523.25
CS5 = 554.37
D5 = 587.33
E5 = 659.25
F5 = 698.46
A5 = 880.00
EB5 = 622.25


class Noise:
    """Deterministic LCG noise (seed 1909), mapped to [-1, 1]."""

    def __init__(self, seed=1909):
        self.x = seed

    def white(self):
        self.x = (self.x * 1103515245 + 12345) & 0x7fffffff
        return self.x / 2147483647.0 * 2.0 - 1.0


def tri_from_phase(ph):
    """Triangle wave via 2/pi * asin(sin(phase)), as in sfx.gd."""
    return (2.0 / math.pi) * math.asin(math.sin(ph))


# ---------------------------------------------------------------------------
# Envelopes
# ---------------------------------------------------------------------------

def pluck_env(dur, k):
    """pluck(dur, k) = exp(-k*t/dur)."""

    def env(t):
        return math.exp(-k * t / dur)

    return env


def adsr_env(a, d, s, r, dur):
    """Linear attack, exponential decay to sustain, linear release.

    Interpretation: the note occupies exactly `dur` seconds; the release
    fills the final `r` seconds. The exponential decay approaches the
    sustain level with time constant d/4 (within 2% of s at the end of the
    decay; the sub-1% step into the sustain phase is inaudible).
    """

    def env(t):
        if t < a:
            return t / a
        if t >= dur - r:
            return s * max(0.0, (dur - t) / r)
        if t < a + d:
            return s + (1.0 - s) * math.exp(-4.0 * (t - a) / d)
        return s

    return env


def block_env(dur, a, r):
    """Pad-block envelope: linear attack, full sustain, linear release
    occupying the final `r` seconds of the block (blocks do not overlap)."""

    def env(t):
        if t < a:
            return t / a
        if t > dur - r:
            return max(0.0, (dur - t) / r)
        return 1.0

    return env


# ---------------------------------------------------------------------------
# Additive render helpers (phase starts at 0 at note onset)
# ---------------------------------------------------------------------------

def add_note(buf, t0, dur, freq, amp, env, wave_kind="sine"):
    n = len(buf)
    i0 = int(round(t0 * SR))
    if i0 >= n:
        return
    cnt = min(int(round(dur * SR)), n - i0)
    w = TWO_PI * freq
    if wave_kind == "sine":
        for j in range(cnt):
            t = j / SR
            buf[i0 + j] += amp * env(t) * math.sin(w * t)
    else:  # triangle
        for j in range(cnt):
            t = j / SR
            buf[i0 + j] += amp * env(t) * tri_from_phase(w * t)


def add_noise_hp(buf, t0, dur, amp, rng):
    """First-difference high-passed noise burst (hats/ticks).

    Interpretation: the spec gives no envelope for the bursts; a linear
    fade-out over the burst length avoids an end click.
    """
    n = len(buf)
    i0 = int(round(t0 * SR))
    cnt = int(round(dur * SR))
    prev = rng.white()
    for j in range(cnt):
        cur = rng.white()
        i = i0 + j
        if i < n:
            buf[i] += amp * (1.0 - j / cnt) * (cur - prev)
        prev = cur


def add_kick(buf, t0, amp=0.40, dur=0.09):
    """Kick: sine sweep 140 -> 45 Hz over 70 ms (then hold 45 Hz),
    phase-continuous, pluck(0.09, 5.0)."""
    n = len(buf)
    i0 = int(round(t0 * SR))
    if i0 >= n:
        return
    cnt = min(int(round(dur * SR)), n - i0)
    sweep = 0.07
    slope = (45.0 - 140.0) / sweep
    ph_end = TWO_PI * (140.0 * sweep + 0.5 * slope * sweep * sweep)
    for j in range(cnt):
        t = j / SR
        if t <= sweep:
            ph = TWO_PI * (140.0 * t + 0.5 * slope * t * t)
        else:
            ph = ph_end + TWO_PI * 45.0 * (t - sweep)
        buf[i0 + j] += amp * math.exp(-5.0 * t / dur) * math.sin(ph)


def add_bell(buf, t0, freq, dur, amp=0.26):
    """Toll bell: sine(f) + 0.3*sine(2f), decay pluck(dur, 4.5)."""
    n = len(buf)
    i0 = int(round(t0 * SR))
    if i0 >= n:
        return
    cnt = min(int(round(dur * SR)), n - i0)
    w = TWO_PI * freq
    for j in range(cnt):
        t = j / SR
        e = amp * math.exp(-4.5 * t / dur)
        buf[i0 + j] += e * (math.sin(w * t) + 0.3 * math.sin(2.0 * w * t))


def add_vibrato_tri(buf, t0, dur, freq, amp, env, rate=5.0, depth=0.003):
    """Triangle with phase-continuous vibrato:
    f_inst(t) = f * (1 + depth*sin(2*pi*rate*t)); phase is the integral."""
    n = len(buf)
    i0 = int(round(t0 * SR))
    if i0 >= n:
        return
    cnt = min(int(round(dur * SR)), n - i0)
    for j in range(cnt):
        t = j / SR
        cycles = freq * t + freq * depth * (
            1.0 - math.cos(TWO_PI * rate * t)) / (TWO_PI * rate)
        buf[i0 + j] += amp * env(t) * tri_from_phase(TWO_PI * cycles)


def zeros(n):
    return array("d", bytes(8 * n))


# ---------------------------------------------------------------------------
# 3.2 menu_drone.wav -- the occult lounge table (32 s, D natural minor)
# ---------------------------------------------------------------------------

def render_menu():
    loop = 32.0
    n = int((loop + XFADE_S) * SR)
    buf = zeros(n)

    # Layer 1: drone -- two detuned sines (+0.3 Hz beat ~ every 3.3 s) plus a
    # triangle octave, with a slow amplitude LFO on the sum.
    wa = TWO_PI * D2
    wb = TWO_PI * 73.72
    wc = TWO_PI * D3
    wl = TWO_PI * 0.1
    for i in range(n):
        t = i / SR
        d = (0.20 * math.sin(wa * t) + 0.20 * math.sin(wb * t)
             + 0.08 * tri_from_phase(wc * t))
        buf[i] += d * (1.0 + 0.12 * math.sin(wl * t))

    # Layer 2: pad -- four 8 s chords; detune pairs at f and f+0.4 Hz, each
    # voice amp 0.06, attack 2 s / release 2 s inside each block. Block 4
    # (= chord 0 again, next cycle) covers the extra crossfade tail.
    chords = [
        (D3, F3, A3),    # Dm
        (BB2, D3, F3),   # Bb
        (G2, BB2, D3),   # Gm
        (A2, CS3, E3),   # A -- the harmonic-minor dominant; resolving back
    ]                    # into Dm at 0 s IS the hook
    env_pad = block_env(8.0, 2.0, 2.0)
    for blk in range(5):
        for f in chords[blk % 4]:
            for det in (0.0, 0.4):
                add_note(buf, 8.0 * blk, 8.0, f + det, 0.06, env_pad, "tri")

    # Layer 3: bell arp -- one note every 4 s starting at t = 2 s; the last
    # bell (C#5, leading tone) rings across the loop seam by design.
    seq = [D5, A4, F5, D5, C5, A4, BB4, CS5]
    env_bell = pluck_env(2.5, 5.0)
    for j, f in enumerate(seq):
        add_note(buf, 2.0 + 4.0 * j, 2.5, f, 0.10, env_bell, "sine")

    return buf, int(loop * SR)


# ---------------------------------------------------------------------------
# 3.3 combat_loop.wav -- the duel (96 BPM, 4/4, 8 bars, D Phrygian)
# ---------------------------------------------------------------------------

BIOME_KEYS = {
    # name, semitone shift from the D-minor original, brightness (major third instead of minor)
    "life":   (+5, True),    # up a fourth, major -- the Orchard is the one place you survive in
    "mind":   (+2, False),   # up a tone, minor -- cold and exact
    "death":  (-3, False),   # down a minor third -- heavy, low, patient
    "chaos":  (+7, False),   # up a fifth -- bright and unstable
    "nature": (0, True),     # home key, major -- growth on familiar ground
}


def _shift(f, semis):
    return f * (2.0 ** (semis / 12.0))


def render_combat(semis=0, bright=False):
    loop = 20.0
    n = int((loop + XFADE_S) * SR)
    buf = zeros(n)
    six = 0.15625   # sixteenth
    bar = 2.5

    # Progression, 2 bars each: Dm | Eb | Dm | Cm.
    # arp = chord tones at octave 4: [root, third, fifth, root+12].
    # A major third is 4 semitones over the root, a minor third 3 -- that one semitone is the whole
    # difference between the Orchard and the Catacombs, and it costs a single number.
    th = 4.0 / 3.0 if bright else 1.0
    def k(f):
        return _shift(f, semis)
    def kt(f, root):
        return _shift(f, semis) * (th if bright else 1.0) if False else _shift(f, semis)
    dm = {"r2": k(D2), "r3": k(D3),
          "arp": (k(D4), _shift(F4, semis + (1 if bright else 0)), k(A4), k(D5)),
          "pad": (k(D3), _shift(F3, semis + (1 if bright else 0)), k(A3))}
    eb = {"r2": k(EB2), "r3": k(EB3),
          "arp": (k(EB4), _shift(G4, semis + (1 if bright else 0)), k(BB4), k(EB5)),
          "pad": (k(EB3), _shift(G3, semis + (1 if bright else 0)), k(BB3))}
    cm = {"r2": k(C2), "r3": k(C3),
          "arp": (k(C4), _shift(EB4, semis + (1 if bright else 0)), k(G4), k(C5)),
          "pad": (k(C3), _shift(EB3, semis + (1 if bright else 0)), k(G3))}
    prog = [dm, eb, dm, cm]

    env_bass = adsr_env(0.005, 0.10, 0.6, 0.15, 0.3125)   # note = one eighth
    env_arp = pluck_env(0.12, 6.0)
    arp_pat = [0, 1, 2, 3, 2, 1, 0, 1, 2, 3, 2, 1, 0, 1, 2, 3]

    # Bar 8 = first bar of the next cycle: covers the crossfade tail.
    for b in range(9):
        ch = prog[(b % 8) // 2]
        bt = b * bar
        # 1. bass: chord root (oct 2) on sixteenth-steps 0/6/8/14; step 8 an
        #    octave up.
        for st in (0, 6, 8, 14):
            f = ch["r3"] if st == 8 else ch["r2"]
            add_note(buf, bt + st * six, 0.3125, f, 0.30, env_bass, "tri")
        # 2. arp: straight sixteenths, accents x1.41 on steps 0/4/8/12.
        for st in range(16):
            f = ch["arp"][arp_pat[st]]
            amp = 0.11 * (1.41 if st % 4 == 0 else 1.0)
            add_note(buf, bt + st * six, 0.12, f, amp, env_arp, "sine")
        # 4. kick on beats 1 and 3.
        for beat in (0, 2):
            add_kick(buf, bt + beat * 0.625)

    # 3. pad: current chord at octave 3 per 2-bar (5 s) block; "detune
    #    +/-0.4 Hz" read as voices at f-0.4 and f+0.4; "amp 0.10 total"
    #    split evenly over the 6 voices.
    env_pad = block_env(5.0, 0.8, 1.2)
    for blk in range(5):
        ch = prog[blk % 4]
        for f in ch["pad"]:
            for det in (-0.4, 0.4):
                add_note(buf, blk * 5.0, 5.0, f + det, 0.10 / 6.0,
                         env_pad, "tri")

    # 5. hats: high-passed noise 25 ms on offbeat sixteenths 2/6/10/14; one
    #    dedicated LCG stream so the layer is order-independent.
    rng = Noise(1909)
    for b in range(9):
        for st in (2, 6, 10, 14):
            add_noise_hp(buf, b * bar + st * six, 0.025, 0.07, rng)

    return buf, int(loop * SR)


# ---------------------------------------------------------------------------
# 3.4 boss_loop.wav -- the Major Arcana made flesh (80 BPM, 8 bars,
#     D Phrygian dominant)
# ---------------------------------------------------------------------------

def render_boss():
    loop = 24.0
    n = int((loop + XFADE_S) * SR)
    buf = zeros(n)
    eighth = 0.375
    bar = 3.0

    # 1. deep drone, continuous.
    w1, w2, w3 = TWO_PI * D1, TWO_PI * D2, TWO_PI * 73.92
    for i in range(n):
        t = i / SR
        buf[i] += (0.18 * math.sin(w1 * t) + 0.10 * math.sin(w2 * t)
                   + 0.10 * math.sin(w3 * t))

    # 2. bass ostinato per bar: eighth-steps [D2, D2, rest, D2, Eb2, rest,
    #    C#2, rest] -- the half-step shudder. Bar 8 = next cycle.
    ost = [(0, D2), (1, D2), (3, D2), (4, EB2), (6, CS2)]
    env_bass = pluck_env(0.35, 4.0)
    for b in range(9):
        for st, f in ost:
            add_note(buf, b * bar + st * eighth, 0.35, f, 0.32,
                     env_bass, "tri")

    # 3. pad chords, 2 bars (6 s) each: D | Eb | D | Cm; detune pairs at f
    #    and f+0.4 Hz (as in the menu pad), "amp 0.09 total" split evenly
    #    over the 6 voices; vibrato 5 Hz, depth 0.3% of f.
    chords = [
        (D3, FS3, A3),   # D major -- Phrygian-dominant I
        (EB3, G3, BB3),  # Eb
        (D3, FS3, A3),
        (C3, EB3, G3),   # Cm
    ]
    env_pad = block_env(6.0, 1.0, 1.5)
    for blk in range(5):
        for f in chords[blk % 4]:
            for det in (0.0, 0.4):
                add_vibrato_tri(buf, blk * 6.0, 6.0, f + det, 0.09 / 6.0,
                                env_pad)

    # 4. toll bell: D4 at the start of bars 1, 3, 7 (t = 0, 6, 18; t = 24 is
    #    the next-cycle bar-1 toll for the seam). Bar 5 (t = 12) is the
    #    tritone stab [D4 + Ab4], decay 1.8 s; each stab tone keeps the full
    #    bell amp 0.26 -- the mid-loop wound is meant to hit harder than a
    #    single toll (peak normalization absorbs the level).
    for bt in (0.0, 6.0, 18.0, 24.0):
        add_bell(buf, bt, D4, 2.2)
    add_bell(buf, 12.0, D4, 1.8)
    add_bell(buf, 12.0, AB4, 1.8)

    # 5. tick: high-passed noise 20 ms on every beat (0.75 s) -- the
    #    metronome of the enrage clock; dedicated LCG stream.
    rng = Noise(1909)
    t = 0.0
    while t < loop + XFADE_S:
        add_noise_hp(buf, t, 0.020, 0.05, rng)
        t += 0.75

    return buf, int(loop * SR)


# ---------------------------------------------------------------------------
# 3.5 heartbeat_loop.wav -- enrage stem (4 s, 4 beats at 60 BPM)
# ---------------------------------------------------------------------------

def render_heartbeat():
    loop = 4.0
    n = int((loop + XFADE_S) * SR)
    buf = zeros(n)

    # "Lub-dub" at t = 0, 1, 2, 3 s (t = 4 is the next-cycle pair for the
    # seam). "Same envelope" for the dub = pluck with k = 6.0 over its own
    # 80 ms duration.
    for k in range(5):
        t0 = float(k)
        add_note(buf, t0, 0.10, 52.0, 0.90, pluck_env(0.10, 6.0), "sine")
        add_note(buf, t0 + 0.18, 0.08, 48.0, 0.65, pluck_env(0.08, 6.0),
                 "sine")

    # One-pole low-pass applied once to the whole stem.
    y = 0.0
    for i in range(n):
        y = 0.6 * y + 0.4 * buf[i]
        buf[i] = y

    return buf, int(loop * SR)


# ---------------------------------------------------------------------------
# Finalize: loop-seam crossfade, cut, peak-normalize, write
# ---------------------------------------------------------------------------

def finalize(buf, loop_n):
    """Equal-power crossfade the extra 0.5 s tail into the head, cut to the
    exact loop length, peak-normalize to 0.71, quantize to int16."""
    out = buf[:loop_n]
    for i in range(XFADE_N):
        t = i / XFADE_N
        out[i] = (buf[i] * math.sqrt(t)
                  + buf[loop_n + i] * math.sqrt(1.0 - t))
    peak = max(abs(v) for v in out)
    gain = PEAK / peak
    pcm = array("h", (int(round(v * gain * 32767.0)) for v in out))
    if sys.byteorder == "big":
        pcm.byteswap()   # WAV data is little-endian
    return pcm


def write_wav(path, pcm):
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    tracks = [
        ("menu_drone.wav", render_menu),
        ("combat_loop.wav", render_combat),
        ("boss_loop.wav", render_boss),
        ("heartbeat_loop.wav", render_heartbeat),
    ]
    for bname, (semis, bright) in sorted(BIOME_KEYS.items()):
        tracks.append(("combat_%s.wav" % bname,
                       (lambda sm, br: (lambda: render_combat(sm, br)))(semis, bright)))
    for name, render in tracks:
        buf, loop_n = render()
        pcm = finalize(buf, loop_n)
        path = os.path.join(OUT_DIR, name)
        write_wav(path, pcm)
        print("wrote %s  (%d samples, %.3f s)"
              % (path, len(pcm), len(pcm) / SR))


if __name__ == "__main__":
    main()
