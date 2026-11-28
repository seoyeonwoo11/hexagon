#!/usr/bin/env python3
"""Hexagon의 효과음과 배경음을 코드로 합성한다 (샘플이나 외부 음원을 전혀 쓰지 않음).

만든 소리는 이 저장소의 것이라 저작권 걱정이 없다.

    pip install numpy scipy
    python3 tools/gen_sounds.py            # 전부 다시 만들기
    python3 tools/gen_sounds.py kill wave  # 이름을 주면 그 효과음만

결과:
    assets/sounds/sfx/<이름>.wav    (16비트 모노 44.1kHz)
    assets/sounds/music/<이름>.ogg  (스테레오 Vorbis, 끊김 없이 이어지는 반복 구간)
배경음 인코딩에는 ffmpeg(libvorbis)가 필요하다.

소리 이름은 scripts/sfx.gd의 SOUNDS와 같아야 한다.
"""
from __future__ import annotations

import os
import subprocess
import sys
import tempfile
import wave

import numpy as np
from scipy import signal

SR = 44100
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SFX_DIR = os.path.join(ROOT, "assets", "sounds", "sfx")
MUSIC_DIR = os.path.join(ROOT, "assets", "sounds", "music")

rng = np.random.default_rng(1234)


# ---------------------------------------------------------------- 기본 재료

def t_of(dur: float) -> np.ndarray:
    return np.arange(int(dur * SR)) / SR


def midi(n: float) -> float:
    return 440.0 * 2.0 ** ((n - 69) / 12.0)


def phase(freq) -> np.ndarray:
    """주파수 배열(또는 상수)을 위상으로 적분한다 (피치가 바뀌어도 끊기지 않게)."""
    return 2 * np.pi * np.cumsum(np.asarray(freq, dtype=float)) / SR


def sweep(f0: float, f1: float, dur: float, curve: float = 1.0) -> np.ndarray:
    """f0에서 f1으로 지수 곡선으로 움직이는 주파수 배열."""
    x = np.linspace(0.0, 1.0, int(dur * SR)) ** curve
    return f0 * (f1 / f0) ** x


def sine(freq, dur=None):
    if np.isscalar(freq):
        freq = np.full(int(dur * SR), float(freq))
    return np.sin(phase(freq))


def saw(freq, dur=None):
    if np.isscalar(freq):
        freq = np.full(int(dur * SR), float(freq))
    p = phase(freq) / (2 * np.pi)
    return 2.0 * (p - np.floor(p + 0.5))


def square(freq, dur=None, duty=0.5):
    if np.isscalar(freq):
        freq = np.full(int(dur * SR), float(freq))
    p = (phase(freq) / (2 * np.pi)) % 1.0
    return np.where(p < duty, 1.0, -1.0)


def tri(freq, dur=None):
    if np.isscalar(freq):
        freq = np.full(int(dur * SR), float(freq))
    p = (phase(freq) / (2 * np.pi)) % 1.0
    return 4.0 * np.abs(p - 0.5) - 1.0


def noise(dur):
    return rng.uniform(-1.0, 1.0, int(dur * SR))


def env(n: int, attack=0.005, decay=None, release=0.02, sustain=1.0, hold=None):
    """간단한 엔벨로프. decay가 있으면 그 시간 상수로 지수 감쇠."""
    t = np.arange(n) / SR
    e = np.ones(n)
    if decay is not None:
        e = np.exp(-np.maximum(t - attack, 0.0) / decay)
        e = sustain + (1.0 - sustain) * e if sustain < 1.0 else e
    a = max(int(attack * SR), 1)
    e[:a] *= np.linspace(0.0, 1.0, a)
    r = min(max(int(release * SR), 1), n)
    e[-r:] *= np.linspace(1.0, 0.0, r)
    return e


def lp(x, cutoff, order=2):
    b, a = signal.butter(order, min(cutoff / (SR / 2), 0.99), "low")
    return signal.lfilter(b, a, x)


def hp(x, cutoff, order=2):
    b, a = signal.butter(order, min(cutoff / (SR / 2), 0.99), "high")
    return signal.lfilter(b, a, x)


def bp(x, lo, hi, order=2):
    b, a = signal.butter(order, [lo / (SR / 2), min(hi / (SR / 2), 0.99)], "band")
    return signal.lfilter(b, a, x)


def sweep_lp(x, f0, f1):
    """잘리는 주파수가 시간에 따라 움직이는 저역 통과 (구간별로 계수를 바꿈)."""
    out = np.zeros_like(x)
    block = 256
    zi = None
    freqs = np.geomspace(max(f0, 20), max(f1, 20), max(len(x) // block, 1) + 1)
    for i, start in enumerate(range(0, len(x), block)):
        b, a = signal.butter(2, min(freqs[min(i, len(freqs) - 1)] / (SR / 2), 0.99), "low")
        if zi is None:
            zi = signal.lfilter_zi(b, a) * 0.0
        out[start:start + block], zi = signal.lfilter(b, a, x[start:start + block], zi=zi)
    return out


def mix(*parts):
    n = max(len(p) for p in parts)
    out = np.zeros(n)
    for p in parts:
        out[:len(p)] += p
    return out


def at(x, offset):
    return np.concatenate([np.zeros(int(offset * SR)), x])


def echo(x, delay=0.09, fb=0.35, taps=4):
    d = int(delay * SR)
    out = np.concatenate([x, np.zeros(d * taps)])
    for k in range(1, taps + 1):
        out[d * k:d * k + len(x)] += x * (fb ** k)
    return out


def finish(x, peak=0.9, fade=0.01):
    x = hp(np.asarray(x, dtype=float), 25)  # 직류 성분 제거
    f = min(int(fade * SR), len(x))
    if f > 0:
        x[-f:] *= np.linspace(1.0, 0.0, f)
    m = np.max(np.abs(x)) or 1.0
    return x / m * peak


def tone(freq, dur, wave_fn=sine, attack=0.004, decay=0.1, release=0.02):
    x = wave_fn(freq, dur)
    return x * env(len(x), attack=attack, decay=decay, release=release)


def chime(freq, dur, decay=0.15):
    """종 비슷한 소리: 기본음 + 배음."""
    x = sine(freq, dur) + 0.4 * sine(freq * 2.01, dur) + 0.18 * sine(freq * 3.03, dur)
    return x * env(len(x), attack=0.002, decay=decay, release=0.03)


# ---------------------------------------------------------------- 효과음

def s_click():
    x = tone(sweep(2400, 1600, 0.035), 0.035, sine, attack=0.001, decay=0.012)
    return finish(x, 0.6)


def s_deny():
    a = lp(tone(220, 0.08, square, decay=0.05), 1800)
    b = lp(tone(165, 0.12, square, decay=0.07), 1800)
    return finish(mix(a, at(b, 0.085)), 0.55)


def s_laser():
    d = 0.09
    x = 0.6 * saw(sweep(1100, 700, d), d) + 0.4 * sine(sweep(2200, 1400, d), d)
    x = lp(x, 3500) * env(len(x), attack=0.002, decay=0.03)
    return finish(x, 0.45)


def s_core_shot():
    d = 0.12
    x = sine(sweep(1500, 420, d, 0.6), d) + 0.3 * square(sweep(750, 210, d, 0.6), d)
    x = lp(x, 4000) * env(len(x), attack=0.001, decay=0.04)
    click = hp(noise(0.01), 3000) * 0.4
    return finish(mix(x, click), 0.55)


def s_spark():
    d = 0.16
    n = bp(noise(d), 2500, 7000)
    # 불규칙하게 끊기는 지직 소리
    gate = (rng.uniform(0, 1, int(d * 400)) > 0.45).astype(float)
    gate = np.repeat(gate, int(np.ceil(len(n) / len(gate))))[:len(n)]
    n *= lp(gate, 900)
    z = 0.5 * square(sweep(1800, 3200, d), d, 0.3)
    x = (n + lp(z, 5000)) * env(len(n), attack=0.002, decay=0.05)
    return finish(x, 0.5)


def s_arrow():
    d = 0.11
    w = bp(noise(d), 1500, 6000) * np.linspace(0.3, 1.0, int(d * SR)) * env(int(d * SR), 0.01, 0.04)
    tw = tone(sweep(900, 600, 0.07), 0.07, tri, decay=0.025)
    return finish(mix(w * 0.8, tw), 0.45)


def s_flame():
    """BURN 화염방사: 짧게 훅 뿜는 불길 + 타닥거리는 불씨."""
    d = 0.38
    n = noise(d)
    roar = sweep_lp(bp(n, 150, 3000), 2600, 700) * env(int(d * SR), 0.03, 0.12, 0.08)
    crackle = np.zeros(int(d * SR))
    for _ in range(9):
        pos = int(rng.uniform(0.02, d - 0.03) * SR)
        c = hp(noise(0.006), 2500) * rng.uniform(0.3, 0.8)
        crackle[pos:pos + len(c)] += c
    low = sine(sweep(90, 60, d), d) * env(int(d * SR), 0.03, 0.1) * 0.4
    return finish(mix(roar, crackle * 0.5, low), 0.5)


def s_shock():
    """SHOCK 충격파: 낮게 쿵 + 퍼져 나가며 내려가는 링 소리 + 짧은 지지직."""
    d = 0.55
    thump = sine(sweep(140, 45, 0.3, 0.5), 0.3) * env(int(0.3 * SR), 0.002, 0.08)
    ring = (sine(sweep(1400, 380, d, 0.6), d) + 0.35 * tri(sweep(2100, 570, d, 0.6), d)) \
        * env(int(d * SR), 0.004, 0.14, 0.05) * 0.45
    buzz = bp(noise(0.12), 2500, 9000) * env(int(0.12 * SR), 0.001, 0.03) * 0.35
    whoosh = sweep_lp(noise(d), 3000, 300) * env(int(d * SR), 0.01, 0.12) * 0.3
    return finish(mix(thump, ring, buzz, whoosh), 0.5)


def s_frost():
    d = 0.45
    parts = [chime(f, d, 0.12) * g for f, g in ((2093, 0.6), (2637, 0.45), (3136, 0.35))]
    shimmer = hp(noise(d), 6000) * env(int(d * SR), 0.02, 0.12) * 0.25
    x = mix(*[at(p, i * 0.025) for i, p in enumerate(parts)], shimmer)
    return finish(x, 0.42)


def s_orbit():
    d = 0.07
    x = tone(sweep(520, 980, d), d, sine, decay=0.03) + 0.2 * tone(sweep(1040, 1960, d), d, tri, decay=0.02)
    return finish(x, 0.4)


def s_drone():
    d = 0.08
    x = lp(square(sweep(240, 120, d), d, 0.35), 1600) * env(int(d * SR), 0.002, 0.03)
    return finish(mix(x, hp(noise(0.015), 2000) * 0.3), 0.45)


def s_explode():
    d = 0.5
    n = sweep_lp(noise(d), 5000, 250) * env(int(d * SR), 0.002, 0.13)
    sub = sine(sweep(130, 38, d, 0.5), d) * env(int(d * SR), 0.002, 0.15)
    return finish(mix(n * 0.9, sub), 0.6)


def s_crit():
    d = 0.22
    x = chime(1760, d, 0.06) + 0.7 * chime(2794, d, 0.05)
    return finish(mix(x, hp(noise(0.02), 4000) * 0.3), 0.5)


def s_kill():
    d = 0.09
    x = tone(sweep(700, 1700, d, 0.7), d, sine, decay=0.035)
    x += 0.35 * tone(sweep(1400, 3400, d, 0.7), d, tri, decay=0.025)
    pop = lp(noise(0.03), 3000) * env(int(0.03 * SR), 0.001, 0.008) * 0.5
    return finish(mix(x, pop), 0.5)


def s_boss_kill():
    d = 1.4
    boom = mix(s_explode() * 1.0, at(s_explode() * 0.6, 0.12))
    notes = [76, 72, 69, 64, 57]
    fall = mix(*[at(tone(midi(n), 0.5, saw, decay=0.15), i * 0.09) for i, n in enumerate(notes)])
    fall = lp(fall, 3000)
    sparkle = mix(*[at(chime(midi(88 + (i % 3) * 5), 0.3, 0.07) * 0.4, 0.05 + i * 0.07) for i in range(8)])
    x = mix(boom, fall * 0.5, sparkle)
    return finish(echo(x[:int(d * SR)], 0.12, 0.3, 3), 0.75)


def s_tile_hit():
    d = 0.12
    x = sine(sweep(160, 70, d), d) * env(int(d * SR), 0.001, 0.04)
    n = lp(noise(0.05), 1800) * env(int(0.05 * SR), 0.001, 0.015) * 0.5
    return finish(mix(x, n), 0.5)


def s_tile_break():
    d = 0.7
    shards = mix(*[at(chime(rng.uniform(1800, 5200), 0.35, rng.uniform(0.03, 0.08))
                      * rng.uniform(0.2, 0.5), rng.uniform(0, 0.12)) for _ in range(14)])
    n = hp(noise(0.4), 2500) * env(int(0.4 * SR), 0.001, 0.08) * 0.6
    boom = sine(sweep(110, 40, 0.4), 0.4) * env(int(0.4 * SR), 0.002, 0.12)
    return finish(mix(shards, n, boom)[:int(d * SR)], 0.65)


def s_boss_appear():
    d = 1.6
    t = t_of(d)
    swell = np.minimum(t / 0.9, 1.0) ** 2 * np.exp(-np.maximum(t - 1.0, 0) / 0.25)
    drone = saw(55, d) + saw(55.7, d) + 0.6 * saw(82.4, d)
    drone = sweep_lp(drone, 200, 1600) * swell
    pulse = (0.5 + 0.5 * np.sign(np.sin(2 * np.pi * 4 * t))) * 0.25
    alarm = lp(square(np.where((t * 4) % 1 < 0.5, 440, 415), d), 2500) * pulse * swell
    return finish(mix(drone, alarm), 0.7)


def s_overlord():
    d = 2.4
    t = t_of(d)
    swell = np.minimum(t / 1.4, 1.0) ** 2 * np.exp(-np.maximum(t - 1.6, 0) / 0.35)
    drone = saw(41.2, d) + saw(41.6, d) + 0.7 * saw(61.7, d) + 0.5 * saw(82.4 * 0.944, d)
    drone = sweep_lp(drone, 150, 2200) * swell
    hits = mix(*[at(s_explode() * 0.5, k * 0.6) for k in range(3)])
    choir = sum(sine(midi(n), d) for n in (50, 53, 57, 60)) * swell * 0.25
    return finish(mix(drone, hits, choir)[:int(d * SR)], 0.75)


def s_wave():
    d = 0.6
    notes = [57, 64, 69]
    arp = mix(*[at(tone(midi(n), 0.3, saw, decay=0.12), i * 0.07) for i, n in enumerate(notes)])
    arp = sweep_lp(arp, 800, 6000)
    rise = sweep_lp(noise(d), 400, 9000) * np.linspace(0, 1, int(d * SR)) ** 2 * env(int(d * SR), 0.01, None, 0.15) * 0.35
    return finish(echo(mix(arp, rise), 0.11, 0.3, 3), 0.55)


def s_wave_clear():
    notes = [72, 76, 79, 84]
    x = mix(*[at(tone(midi(n), 0.35, square, decay=0.1) * 0.6 + tone(midi(n), 0.35, tri, decay=0.14), i * 0.075)
              for i, n in enumerate(notes)])
    x = lp(x, 6000)
    return finish(echo(x, 0.12, 0.3, 3), 0.5)


def s_card():
    x = mix(chime(midi(88), 0.3, 0.07), at(chime(midi(95), 0.35, 0.09), 0.06))
    return finish(echo(x, 0.1, 0.25, 2), 0.5)


def s_place():
    thunk = sine(sweep(220, 90, 0.15), 0.15) * env(int(0.15 * SR), 0.001, 0.05)
    ping = chime(midi(81), 0.3, 0.08) * 0.5
    return finish(mix(thunk, at(ping, 0.02)), 0.55)


def s_equip():
    a = lp(tone(700, 0.12, square, decay=0.03), 4000) * 0.5
    b = chime(1050, 0.25, 0.06) * 0.6
    c = chime(1575, 0.25, 0.05) * 0.4
    return finish(mix(a, at(b, 0.04), at(c, 0.08)), 0.5)


def s_levelup():
    notes = [69, 73, 76, 81, 85]
    x = mix(*[at(tone(midi(n), 0.3, square, decay=0.08) * 0.4 + tone(midi(n), 0.3, sine, decay=0.12), i * 0.055)
              for i, n in enumerate(notes)])
    sparkle = mix(*[at(chime(midi(93 + (i % 2) * 4), 0.2, 0.05) * 0.25, 0.28 + i * 0.05) for i in range(4)])
    return finish(echo(lp(mix(x, sparkle), 7000), 0.1, 0.3, 3), 0.55)


def s_coin():
    a = tone(midi(83), 0.08, square, decay=0.05)
    b = tone(midi(88), 0.22, square, decay=0.08)
    return finish(lp(mix(a, at(b, 0.07)), 5000), 0.4)


def s_skill_overdrive():
    d = 0.7
    t = t_of(d)
    x = saw(sweep(110, 440, d, 0.8), d) + saw(sweep(111, 444, d, 0.8), d)
    x = sweep_lp(x, 400, 5000) * (0.7 + 0.3 * np.sin(2 * np.pi * 14 * t)) * env(len(t), 0.02, None, 0.2)
    hit = s_explode() * 0.4
    return finish(mix(x, at(hit, 0.55))[:int(1.0 * SR)], 0.65)


def s_skill_freeze():
    notes = [96, 91, 88, 84, 79]
    c = mix(*[at(chime(midi(n), 0.6, 0.18) * 0.5, i * 0.06) for i, n in enumerate(notes)])
    hiss = hp(noise(0.8), 5000) * env(int(0.8 * SR), 0.05, 0.2) * 0.35
    return finish(echo(mix(c, hiss), 0.13, 0.3, 3), 0.6)


def s_skill_repair():
    d = 0.9
    x = sum(sine(sweep(midi(n) * 0.5, midi(n), d, 0.4), d) for n in (60, 64, 67, 72))
    x = x * env(int(d * SR), 0.05, None, 0.35)
    sparkle = mix(*[at(chime(midi(84 + k * 3), 0.3, 0.06) * 0.25, 0.2 + k * 0.08) for k in range(5)])
    return finish(mix(x, sparkle), 0.55)


def s_skill_nova():
    boom = mix(s_explode(), at(s_explode() * 0.7, 0.05))
    ring = sine(sweep(2200, 300, 0.8, 0.5), 0.8) * env(int(0.8 * SR), 0.002, 0.25) * 0.5
    sub = sine(sweep(80, 30, 1.0), 1.0) * env(int(1.0 * SR), 0.002, 0.35)
    return finish(mix(boom, ring, sub), 0.75)


def s_skill_warp():
    # 빨려 들어갔다가 튕겨 나가는 소리: 내려가는 휘파람 + 올라가는 펑
    d = 0.75
    t = t_of(d)
    down = sine(sweep(1800, 220, 0.25, 0.6), 0.25) * env(int(0.25 * SR), 0.01, None, 0.05) * 0.5
    up = saw(sweep(90, 900, d, 0.4), d) + saw(sweep(91, 905, d, 0.4), d)
    up = sweep_lp(up, 300, 4000) * (0.75 + 0.25 * np.sin(2 * np.pi * 22 * t)) * env(len(t), 0.005, None, 0.35)
    sub = sine(sweep(70, 35, 0.6), 0.6) * env(int(0.6 * SR), 0.002, 0.25) * 0.7
    return finish(echo(mix(down, at(up * 0.6, 0.2), at(sub, 0.2)), 0.11, 0.3, 3), 0.65)


def s_gameover():
    notes = [(69, 0.0), (65, 0.32), (62, 0.64), (57, 1.0)]
    lead = mix(*[at(lp(tone(midi(n), 0.9, saw, attack=0.01, decay=0.35, release=0.2), 2000), s) for n, s in notes])
    pad_d = 2.4
    pad = sum(saw(midi(n), pad_d) + saw(midi(n) * 1.004, pad_d) for n in (45, 52, 57)) * 0.25
    pad = lp(pad, 900) * env(int(pad_d * SR), 0.4, None, 1.0)
    return finish(echo(mix(lead * 0.8, pad), 0.18, 0.35, 4)[:int(3.0 * SR)], 0.7)


def s_victory():
    seq = [(72, 0.0, 0.14), (76, 0.14, 0.14), (79, 0.28, 0.14), (84, 0.42, 0.5),
           (81, 0.95, 0.14), (84, 1.09, 0.14), (88, 1.23, 0.9)]
    lead = mix(*[at(tone(midi(n), d + 0.15, square, attack=0.005, decay=d * 1.2, release=0.08) * 0.5
                    + tone(midi(n), d + 0.15, saw, decay=d, release=0.08) * 0.4, s) for n, s, d in seq])
    lead = lp(lead, 5000)
    pad_d = 2.6
    pad = sum(saw(midi(n), pad_d) + saw(midi(n) * 1.005, pad_d) for n in (48, 55, 60, 64)) * 0.18
    pad = lp(pad, 1400) * env(int(pad_d * SR), 0.15, None, 0.8)
    sparkle = mix(*[at(chime(midi(96 + (k % 3) * 3), 0.3, 0.06) * 0.2, 1.25 + k * 0.07) for k in range(10)])
    return finish(echo(mix(lead, pad, sparkle), 0.14, 0.3, 4)[:int(3.2 * SR)], 0.75)


SFX = {name[2:]: fn for name, fn in globals().items() if name.startswith("s_") and callable(fn)}


def write_wav(path: str, x: np.ndarray) -> None:
    data = (np.clip(x, -1.0, 1.0) * 32767).astype("<i2")
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data.tobytes())


# ---------------------------------------------------------------- 배경음

class Track:
    """스테레오 버퍼에 음을 더해 가는 작은 시퀀서. 길이는 반복 구간, 꼬리는 앞에 겹쳐 끊김 없이 이어진다."""

    def __init__(self, bpm: float, bars: int):
        self.beat = 60.0 / bpm
        self.length = int(bars * 4 * self.beat * SR)
        self.buf = np.zeros((2, self.length + SR * 4))

    def add(self, x: np.ndarray, beat: float, pan: float = 0.0, gain: float = 1.0):
        start = int(beat * self.beat * SR)
        end = min(start + len(x), self.buf.shape[1])
        x = x[:end - start] * gain
        self.buf[0, start:end] += x * np.sqrt(0.5 * (1 - pan))
        self.buf[1, start:end] += x * np.sqrt(0.5 * (1 + pan))

    def render(self, delay_beats: float = 0.75, fb: float = 0.3, peak: float = 0.8) -> np.ndarray:
        # 핑퐁 딜레이
        d = int(delay_beats * self.beat * SR)
        out = self.buf.copy()
        for k in range(1, 5):
            src = self.buf * (fb ** k)
            ch = k % 2
            out[ch, d * k:] += (src[0] + src[1])[:out.shape[1] - d * k] * 0.5
        # 꼬리를 앞으로 접어 반복 이음매를 없앤다
        loop = out[:, :self.length].copy()
        tail = out[:, self.length:]
        n = 0
        while n < tail.shape[1]:
            seg = tail[:, n:n + self.length]
            loop[:, :seg.shape[1]] += seg
            n += self.length
        m = np.max(np.abs(loop)) or 1.0
        return loop / m * peak


def i_bass(freq, dur, cutoff=700, drive=1.0):
    x = saw(freq, dur) + 0.6 * saw(freq * 1.005, dur) + 0.5 * square(freq * 0.5, dur)
    x = np.tanh(x * drive)
    e = env(len(x), 0.004, None, 0.03)
    return lp(x, cutoff) * e * np.exp(-t_of(dur) / (dur * 1.5 + 0.05))


def i_pad(freqs, dur, cutoff=1100):
    x = np.zeros(int(dur * SR))
    for f in freqs:
        for det in (0.996, 1.0, 1.004):
            x += saw(f * det, dur)
    x = lp(x / (len(freqs) * 3), cutoff)
    return x * env(len(x), min(0.6, dur * 0.3), None, min(0.8, dur * 0.4))


def i_pluck(freq, dur=0.25, cutoff=3500, wave_fn=square):
    x = wave_fn(freq, dur) * 0.6 + saw(freq * 1.003, dur) * 0.4
    return sweep_lp(x, cutoff, 400) * env(len(x), 0.002, dur * 0.35, 0.02)


def i_kick(dur=0.35):
    x = sine(sweep(160, 42, dur, 0.35), dur) * env(int(dur * SR), 0.001, 0.12)
    return mix(np.tanh(x * 1.6), lp(noise(0.01), 2000) * 0.2)


def i_snare(dur=0.22):
    n = bp(noise(dur), 900, 7000) * env(int(dur * SR), 0.001, 0.06)
    body = sine(sweep(240, 160, dur), dur) * env(int(dur * SR), 0.001, 0.04) * 0.6
    return n + body


def i_hat(dur=0.05, open_=False):
    d = 0.18 if open_ else dur
    return hp(noise(d), 8000) * env(int(d * SR), 0.001, 0.06 if open_ else 0.012)


CHORDS = {
    # 이름: (베이스 MIDI, 패드 음들)
    "Am": (45, (57, 60, 64)), "F": (41, (53, 57, 60)), "C": (48, (55, 60, 64)),
    "G": (43, (55, 59, 62)), "Dm": (50, (57, 62, 65)), "E": (40, (56, 59, 64)),
    "Em": (40, (55, 59, 64)), "Bb": (46, (58, 62, 65)), "Gm": (43, (55, 58, 62)),
    "Eb": (39, (55, 58, 63)), "Cm": (48, (55, 60, 63)), "A": (45, (57, 61, 64)),
}


def m_menu():
    """시작 화면: 느리고 잔잔한 패드 + 반짝이는 아르페지오, 드럼 없음."""
    tr = Track(bpm=76, bars=16)
    prog = ["Am", "F", "C", "G"] * 4
    for bar, name in enumerate(prog):
        b0 = bar * 4
        bass, pad = CHORDS[name]
        tr.add(i_pad([midi(n) for n in pad], 4 * tr.beat + 1.0, 900), b0, 0.0, 0.5)
        tr.add(lp(sine(midi(bass - 12), 4 * tr.beat), 300) * env(int(4 * tr.beat * SR), 0.3, None, 0.8), b0, 0, 0.35)
        arp = [pad[0] + 12, pad[1] + 12, pad[2] + 12, pad[1] + 24]
        for k in range(8):
            if bar >= 2 or k % 2 == 0:
                n = arp[k % 4]
                tr.add(i_pluck(midi(n), 0.5, 2400, tri), b0 + k * 0.5, -0.4 if k % 2 else 0.4, 0.16)
    return tr.render(delay_beats=0.75, fb=0.35, peak=0.7)


def drums(tr: Track, bar: int, fill: bool, hats16: bool, gain=1.0):
    b0 = bar * 4
    for k in range(4):
        tr.add(i_kick(), b0 + k, 0, 0.9 * gain)
    for k in (1, 3):
        tr.add(i_snare(), b0 + k, 0.05, 0.45 * gain)
    steps = 16 if hats16 else 8
    for k in range(steps):
        pos = b0 + k * (4 / steps)
        accent = 1.0 if (k % (steps // 4)) == (steps // 8) else 0.55
        tr.add(i_hat(open_=(not hats16 and k % 2 == 1)), pos, 0.3, 0.22 * accent * gain)
    if fill:
        for k in range(4):
            tr.add(i_snare(0.15), b0 + 3 + k * 0.25, -0.1, 0.25 + 0.08 * k)


def m_battle():
    """전투: 112BPM 신스웨이브. 8분음 베이스, 패드, 아르페지오 리드."""
    tr = Track(bpm=112, bars=16)
    prog = ["Am", "F", "C", "G", "Am", "F", "Dm", "E"] * 2
    lead_line = [76, 74, 72, 71, 72, 69, 71, 67]
    for bar, name in enumerate(prog):
        b0 = bar * 4
        bass, pad = CHORDS[name]
        drums(tr, bar, fill=(bar % 8 == 7), hats16=(bar >= 8), gain=0.9)
        for k in range(8):
            n = bass - 12 + (12 if k % 4 == 3 else 0)
            tr.add(i_bass(midi(n), tr.beat * 0.48, 650 + 250 * (k % 2), 1.4), b0 + k * 0.5, 0, 0.55)
        tr.add(i_pad([midi(n) for n in pad], 4 * tr.beat, 1300), b0, 0, 0.3)
        arp = [pad[0] + 12, pad[2] + 12, pad[1] + 12, pad[2] + 12]
        for k in range(16):
            if bar >= 4:
                tr.add(i_pluck(midi(arp[k % 4]), 0.18, 3800), b0 + k * 0.25, 0.5 if k % 2 else -0.5, 0.11)
        if bar >= 8 and bar % 2 == 0:
            n = lead_line[(bar // 2) % len(lead_line)]
            lead = lp(saw(midi(n), tr.beat * 3) * 0.6 + square(midi(n) * 1.002, tr.beat * 3) * 0.4, 2600)
            t = t_of(tr.beat * 3)
            lead *= env(len(lead), 0.04, None, 0.3) * (1 + 0.04 * np.sin(2 * np.pi * 5.5 * t))
            tr.add(lead, b0, 0.1, 0.16)
    return tr.render(delay_beats=0.75, fb=0.28, peak=0.8)


def m_boss():
    """보스 웨이브: 132BPM, 어둡고 몰아치는 16분음 베이스."""
    tr = Track(bpm=132, bars=16)
    prog = ["Dm", "Dm", "Bb", "A", "Dm", "Dm", "Gm", "A"] * 2
    for bar, name in enumerate(prog):
        b0 = bar * 4
        bass, pad = CHORDS[name]
        drums(tr, bar, fill=(bar % 4 == 3), hats16=True, gain=1.0)
        for k in range(16):
            n = bass - 12 + (12 if k % 8 in (3, 6) else 0) + (1 if name == "A" and k % 8 == 7 else 0)
            tr.add(i_bass(midi(n), tr.beat * 0.24, 900 + 500 * (k % 4 == 0), 2.2), b0 + k * 0.25, 0, 0.5)
        tr.add(i_pad([midi(n) for n in pad], 4 * tr.beat, 1600), b0, 0, 0.28)
        # 경고음 같은 리드: 반음 흔들림
        if bar >= 4:
            for k in range(4):
                n = pad[2] + 12 + (1 if k % 2 else 0)
                tr.add(i_pluck(midi(n), 0.3, 3000, saw), b0 + k + 0.5, 0.4 if k % 2 else -0.4, 0.12)
        if bar % 4 == 0:
            hit = sweep_lp(noise(1.2), 6000, 200) * env(int(1.2 * SR), 0.002, 0.3) * 0.5
            tr.add(hit, b0, 0, 0.5)
    return tr.render(delay_beats=0.5, fb=0.25, peak=0.82)


MUSIC = {name[2:]: fn for name, fn in globals().items() if name.startswith("m_") and callable(fn)}


def write_ogg(path: str, stereo: np.ndarray) -> None:
    with tempfile.TemporaryDirectory() as tmp:
        wav_path = os.path.join(tmp, "x.wav")
        data = (np.clip(stereo.T, -1.0, 1.0) * 32767).astype("<i2")
        with wave.open(wav_path, "wb") as w:
            w.setnchannels(2)
            w.setsampwidth(2)
            w.setframerate(SR)
            w.writeframes(data.tobytes())
        subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", wav_path,
                        "-c:a", "libvorbis", "-q:a", "3", path], check=True)


def main(names: list[str]) -> None:
    os.makedirs(SFX_DIR, exist_ok=True)
    os.makedirs(MUSIC_DIR, exist_ok=True)
    for name, fn in SFX.items():
        if names and name not in names:
            continue
        write_wav(os.path.join(SFX_DIR, name + ".wav"), fn())
        print("sfx  ", name)
    for name, fn in MUSIC.items():
        if names and name not in names:
            continue
        write_ogg(os.path.join(MUSIC_DIR, name + ".ogg"), fn())
        print("music", name)


if __name__ == "__main__":
    main(sys.argv[1:])
