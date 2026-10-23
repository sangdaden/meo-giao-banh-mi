"""Tự tổng hợp toàn bộ nhạc và tiếng động của game bằng numpy, không dùng file mẫu nào.

Chạy:  pip install numpy scipy  (cần ffmpeg có libvorbis)
       python3 tools/sound/synth.py            # ghi vào assets/audio/
       python3 tools/sound/synth.py ten1 ten2  # chỉ làm lại vài file

Hiệu ứng ngắn xuất .wav (Godot phát ngay, không phải giải mã), nhạc và tiếng nền
xuất .ogg cho nhẹ. Mọi file đều do script này tạo ra nên thuộc về dự án (CC0),
không vướng giấy phép của ai. Danh sách đầy đủ ở assets/audio/NGUON.md.
"""
import os
import subprocess
import sys
import wave
import zlib

import numpy as np
from scipy.signal import butter, lfilter, sosfilt

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from bark import bark_v2  # noqa: E402
from voice import say  # noqa: E402

SR = 44100
OUT = os.path.join(os.path.dirname(__file__), "..", "..", "assets", "audio")
rng = np.random.default_rng(7)


# ---------------------------------------------------------------- tiện ích

def t_of(dur):
    return np.arange(int(dur * SR)) / SR


def silence(dur):
    return np.zeros(int(dur * SR))


def noise(dur):
    return rng.standard_normal(int(dur * SR))


def brown(dur):
    x = np.cumsum(noise(dur))
    x = lfilter([1, -1], [1, -0.995], x)
    return x / (np.abs(x).max() + 1e-9)


def filt(x, kind, freq, order=2):
    if kind == "band":
        sos = butter(order, [freq[0] / (SR / 2), freq[1] / (SR / 2)], "bandpass", output="sos")
    else:
        sos = butter(order, freq / (SR / 2), kind, output="sos")
    return sosfilt(sos, x)


def env_exp(dur, decay, attack=0.002):
    t = t_of(dur)
    e = np.exp(-t * decay)
    a = int(attack * SR)
    if a > 0:
        e[:a] *= np.linspace(0, 1, a)
    return e


def adsr(n, a, d, s, r):
    a, d, r = int(a * SR), int(d * SR), int(r * SR)
    sus = max(n - a - d - r, 0)
    e = np.concatenate([np.linspace(0, 1, a, endpoint=False), np.linspace(1, s, d, endpoint=False),
                        np.full(sus, s), np.linspace(s, 0, r)])
    return np.pad(e, (0, max(0, n - len(e))))[:n]


def phase_of(freq):
    """freq: hằng số hoặc mảng tần số theo thời gian -> pha tích lũy."""
    return 2 * np.pi * np.cumsum(freq) / SR


def mix_at(buf, x, start, gain=1.0):
    i = int(start * SR)
    if i >= len(buf):
        return
    n = min(len(x), len(buf) - i)
    buf[i:i + n] += x[:n] * gain


def fade(x, fin=0.003, fout=0.01):
    a, b = int(fin * SR), int(fout * SR)
    x = x.copy()
    if a:
        x[:a] *= np.linspace(0, 1, a)
    if b:
        x[-b:] *= np.linspace(1, 0, b)
    return x


def norm(x, peak=0.89):
    m = np.abs(x).max()
    return x * (peak / m) if m > 0 else x


def midi(n):
    return 440.0 * 2 ** ((n - 69) / 12)


NOTE = {"C": 0, "C#": 1, "D": 2, "D#": 3, "E": 4, "F": 5, "F#": 6, "G": 7, "G#": 8, "A": 9, "A#": 10, "Bb": 10, "B": 11}


def note(name):
    p, o = name[:-1], int(name[-1])
    return midi(12 * (o + 1) + NOTE[p])


def reverb(x, wet=0.25, size=1.0, damp=0.4):
    """Schroeder: 4 comb song song + 2 allpass nối tiếp, đủ cho cảm giác phòng nhỏ."""
    out = np.zeros(len(x))
    for d, g in [(1557, 0.84), (1617, 0.83), (1491, 0.82), (1422, 0.81)]:
        d = int(d * size)
        b = np.zeros(d + 1)
        b[0] = 1
        a = np.zeros(d + 1)
        a[0] = 1
        a[d] = -g
        y = lfilter(b, a, x)
        out += filt(y, "low", 6000 * (1 - damp) + 1500)
    for d, g in [(225, 0.5), (556, 0.5)]:
        b = np.zeros(d + 1)
        b[0] = -g
        b[d] = 1
        a = np.zeros(d + 1)
        a[0] = 1
        a[d] = -g
        out = lfilter(b, a, out)
    return x + out * wet * 0.25


def stereo(l, r):
    return np.stack([l, r], axis=1)


def pan(x, p):
    """p từ -1 (trái) đến 1 (phải), có thể là mảng."""
    a = (np.asarray(p) + 1) * np.pi / 4
    return stereo(x * np.cos(a), x * np.sin(a))


# ---------------------------------------------------------------- ghi file

def save(name, x, kind="wav", peak=0.89, q=5):
    x = norm(x, peak)
    os.makedirs(OUT, exist_ok=True)
    data = (np.clip(x, -1, 1) * 32767).astype("<i2")
    ch = 1 if data.ndim == 1 else data.shape[1]
    wav_path = os.path.join(OUT, name + ".wav")
    with wave.open(wav_path, "wb") as w:
        w.setnchannels(ch)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data.tobytes())
    if kind == "ogg":
        ogg = os.path.join(OUT, name + ".ogg")
        subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", wav_path, "-c:a", "libvorbis", "-q:a", str(q), ogg], check=True)
        os.remove(wav_path)
    print("  ", name, kind, "%.2fs" % (len(x) / SR))


def loopify(x, length):
    """Cắt về đúng độ dài vòng lặp, phần đuôi (vang) cộng vòng lên đầu để lặp không bị khựng."""
    n = int(length * SR)
    out = x[:n].copy()
    tail = x[n:]
    while len(tail):
        k = min(len(tail), n)
        out[:k] += tail[:k]
        tail = tail[k:]
    return out


# ---------------------------------------------------------------- nhạc cụ

def pluck(freq, dur, bright=1.0, decay=3.0, slide=0.0):
    """Gảy dây kiểu đàn tranh: nhiều họa âm tắt dần, họa âm cao tắt nhanh hơn.
    slide: luyến từ thấp lên (số bán cung) trong 70 ms đầu, nghe ra chất nhạc dân gian."""
    t = t_of(dur)
    f = np.full(len(t), freq)
    if slide:
        k = np.clip(t / 0.07, 0, 1)
        f = freq * 2 ** (-slide * (1 - k) ** 2 / 12)
    ph = phase_of(f)
    y = np.zeros(len(t))
    for k in range(1, 9):
        amp = (1.0 / k) * (bright ** (k - 1)) * (0.6 if k % 2 == 0 else 1.0)
        y += amp * np.sin(k * ph * (1 + 0.0007 * k)) * np.exp(-t * decay * (1 + 0.45 * k))
    y *= np.minimum(t / 0.002, 1)
    return y


def marimba(freq, dur):
    t = t_of(dur)
    ph = phase_of(np.full(len(t), freq))
    y = np.sin(ph) * np.exp(-t * 5) + 0.35 * np.sin(4 * ph) * np.exp(-t * 18) + 0.12 * np.sin(9.2 * ph) * np.exp(-t * 40)
    return y * np.minimum(t / 0.0015, 1)


def bell(freq, dur, decay=2.5):
    t = t_of(dur)
    y = np.zeros(len(t))
    for r, a, d in [(1, 1, 1), (2.01, 0.5, 1.6), (2.76, 0.4, 2.2), (5.4, 0.22, 3.5), (8.93, 0.1, 5)]:
        y += a * np.sin(2 * np.pi * freq * r * t) * np.exp(-t * decay * d)
    return y * np.minimum(t / 0.001, 1)


def bass(freq, dur):
    t = t_of(dur)
    ph = phase_of(np.full(len(t), freq))
    y = np.sin(ph) + 0.35 * np.sin(2 * ph) + 0.12 * np.sin(3 * ph)
    return y * adsr(len(t), 0.005, 0.1, 0.7, 0.05)


def pad(freqs, dur):
    t = t_of(dur)
    y = np.zeros(len(t))
    for f in freqs:
        for det in (-0.12, 0.0, 0.11):
            ff = f * 2 ** (det / 12)
            ph = 2 * np.pi * ff * t + rng.uniform(0, 6.28)
            # răng cưa mềm: 6 họa âm đầu
            for k in range(1, 7):
                y += np.sin(k * ph) / k * 0.3
    y = filt(y, "low", 1800)
    return y * adsr(len(t), 0.35, 0.3, 0.8, 0.5)


def kick(dur=0.35):
    t = t_of(dur)
    f = 45 + 85 * np.exp(-t * 30)
    return np.sin(phase_of(f)) * np.exp(-t * 9) + 0.15 * filt(noise(dur), "low", 2000) * np.exp(-t * 80)


def snare(dur=0.2, soft=False):
    t = t_of(dur)
    n = filt(noise(dur), "band", (900, 6000)) * np.exp(-t * (28 if soft else 20))
    tone = np.sin(2 * np.pi * 190 * t) * np.exp(-t * 30)
    return n * (0.6 if soft else 1) + 0.4 * tone


def hat(dur=0.06, open_=False):
    t = t_of(dur)
    return filt(noise(dur), "high", 7000) * np.exp(-t * (18 if open_ else 70))


def shaker(dur=0.09):
    t = t_of(dur)
    e = np.sin(np.pi * np.clip(t / dur, 0, 1)) ** 2
    return filt(noise(dur), "band", (4000, 11000)) * e


# ---------------------------------------------------------------- bộ nối nhạc

def song(bpm, bars, chords, melody, inst, parts, length_bars=None, steps_per_bar=8):
    """melody: chuỗi theo ô móc đơn (8 ô/ô nhịp), '~' giữ nốt, '-' nghỉ.
    chords: danh sách hợp âm mỗi ô nhịp, ví dụ ['D3 F#3 A3', ...]."""
    beat = 60 / bpm
    bar = beat * 4
    total = bar * bars
    L = np.zeros(int((total + 4) * SR))
    R = np.zeros_like(L)

    def put(x, start, gain, p=0.0):
        a = (p + 1) * np.pi / 4
        mix_at(L, x, start, gain * np.cos(a))
        mix_at(R, x, start, gain * np.sin(a))

    # giai điệu
    toks = melody.split()
    step = bar / steps_per_bar
    i = 0
    while i < len(toks):
        tk = toks[i]
        if tk not in ("~", "-"):
            j = i + 1
            while j < len(toks) and toks[j] == "~":
                j += 1
            dur = (j - i) * step
            slide = 0.0
            name = tk
            if name.startswith("/"):
                slide, name = 2.0, name[1:]
            x = inst(note(name), dur + 0.6, slide)
            k = min(int(dur * SR), len(x))
            x[k:] *= np.linspace(1, 0, len(x) - k) ** 2
            put(x, i * step, parts.get("melody", 0.5), 0.1)
        i += 1
    for b in range(bars):
        notes = chords[b % len(chords)].split()
        t0 = b * bar
        root = note(notes[0])
        if "pad" in parts:
            put(pad([note(n) for n in notes[1:]] + [root * 2], bar + 0.4), t0, parts["pad"], 0.0)
        if "bass" in parts:
            pattern = parts.get("bass_pattern", [(0, 1, 1.5), (2, 1, 1), (2.5, 2, 0.5), (3, 1, 1)])
            for beat_pos, mult, length in pattern:
                put(bass(root / 2 * mult, length * beat * 0.9), t0 + beat_pos * beat, parts["bass"], 0)
        if "stab" in parts:
            for k in parts.get("stab_beats", [0.5, 1.5, 2.5, 3.5]):
                for n, sp in zip(notes[1:], (-0.4, 0, 0.4)):
                    put(pluck(note(n) * 2, 0.35, 0.5, 9), t0 + k * beat + rng.uniform(0, 0.008), parts["stab"], sp)
        if "arp" in parts:
            seq = [note(n) * 2 for n in notes[1:]] + [root * 4]
            for k in range(8):
                put(marimba(seq[[0, 1, 2, 1, 3, 2, 1, 2][k]], 0.5), t0 + k * beat / 2, parts["arp"], -0.35)
        if "kick" in parts:
            for k in parts.get("kick_beats", [0, 2]):
                put(kick(), t0 + k * beat, parts["kick"])
        if "snare" in parts:
            for k in (1, 3):
                put(snare(soft=True), t0 + k * beat, parts["snare"], 0.1)
        if "hat" in parts:
            for k in range(8):
                g = 1.0 if k % 2 else 0.55
                put(hat(open_=(k == 7)), t0 + k * beat / 2 + (0.02 if parts.get("swing") and k % 2 else 0), parts["hat"] * g, 0.3)
        if "shaker" in parts:
            for k in range(16):
                put(shaker(), t0 + k * beat / 4, parts["shaker"] * (1 if k % 4 == 2 else 0.5), -0.3)
    mixed = stereo(L, R)
    rev = parts.get("reverb", 0.25)
    mixed = np.stack([reverb(mixed[:, 0], rev, 1.0), reverb(mixed[:, 1], rev, 1.07)], axis=1)
    return np.stack([loopify(mixed[:, 0], total), loopify(mixed[:, 1], total)], axis=1)


def tranh(f, dur, slide):
    return pluck(f, dur, 0.75, 2.2, slide)


def mari(f, dur, slide):
    return marimba(f, dur)


def staccato(f, dur, slide):
    return pluck(f, min(dur, 0.25) + 0.1, 0.9, 7, slide)


# ---------------------------------------------------------------- nhạc nền

def music_menu():
    mel = ("B4 ~ D5 ~ E5 ~ D5 ~  B4 ~ A4 ~ G4 ~ ~ ~  G4 ~ A4 ~ B4 ~ /E5 ~  D5 ~ ~ ~ A4 ~ ~ ~ "
           "B4 ~ D5 ~ G5 ~ E5 D5  /E5 ~ D5 ~ B4 ~ ~ ~  A4 ~ B4 ~ D5 ~ E5 D5  /A4 ~ ~ ~ - - - -")
    return song(88, 8, ["G2 B3 D4 G4", "E2 G3 B3 E4", "C2 E3 G3 C4", "D2 F#3 A3 D4"], mel, tranh,
                {"melody": 0.55, "pad": 0.12, "bass": 0.3, "bass_pattern": [(0, 1, 2), (2, 1, 2)],
                 "shaker": 0.05, "reverb": 0.5})


def music_delivery():
    mel = ("F#5 ~ A5 F#5 E5 ~ D5 ~  E5 ~ A4 ~ B4 D5 E5 ~  F#5 ~ A5 ~ B5 A5 F#5 ~  E5 D5 B4 ~ D5 ~ - -  "
           "F#5 ~ A5 F#5 E5 ~ D5 ~  E5 ~ F#5 A5 B5 ~ A5 ~  F#5 E5 D5 ~ B4 ~ D5 E5  D5 ~ - B4 A4 ~ - -")
    return song(126, 8, ["D2 F#3 A3 D4", "A2 E3 A3 C#4", "B2 F#3 B3 D4", "G2 G3 B3 D4"], mel, tranh,
                {"melody": 0.5, "bass": 0.32, "stab": 0.16, "kick": 0.4, "snare": 0.28, "hat": 0.12,
                 "shaker": 0.06, "reverb": 0.22})


def music_chase():
    mel = ("A4 C5 E5 A4 C5 E5 D5 C5  A4 C5 E5 G5 E5 D5 C5 D5  C5 ~ A4 ~ C5 D5 E5 ~  D5 ~ G4 ~ D5 ~ E5 ~  "
           "A5 G5 E5 D5 E5 G5 A5 ~  G5 E5 D5 C5 D5 E5 C5 ~  F5 ~ E5 ~ C5 ~ A4 C5  D5 ~ B4 ~ G4 ~ E5 ~")
    return song(150, 8, ["A2 A3 C4 E4", "A2 A3 C4 E4", "F2 F3 A3 C4", "G2 G3 B3 D4"], mel, staccato,
                {"melody": 0.45, "bass": 0.5,
                 "bass_pattern": [(k * 0.5, 2 if k % 4 == 3 else 1, 0.45) for k in range(8)],
                 "kick": 0.55, "kick_beats": [0, 1, 2, 3], "snare": 0.35, "hat": 0.15, "reverb": 0.15})


def music_kitchen():
    mel = ("A4 ~ C5 A4 G4 ~ F4 ~  A4 ~ D5 ~ C5 A4 ~ ~  G4 ~ A4 ~ C5 ~ D5 C5  A4 ~ G4 ~ ~ ~ - -  "
           "A4 ~ C5 A4 G4 ~ F4 G4  A4 ~ C5 ~ D5 ~ F5 ~  D5 C5 A4 ~ G4 ~ A4 ~  G4 ~ ~ ~ - - - -")
    return song(100, 8, ["F2 A3 C4 F4", "D2 F3 A3 D4", "Bb1 F3 Bb3 D4", "C2 E3 G3 C4"], mel, mari,
                {"melody": 0.6, "bass": 0.35, "bass_pattern": [(0, 1, 1), (1.5, 1, 0.5), (2, 2, 1), (3, 1, 1)],
                 "arp": 0.1, "kick": 0.3, "hat": 0.08, "swing": True, "shaker": 0.04, "reverb": 0.3})


def jingle_win():
    x = silence(3.2)
    for i, n in enumerate(["D5", "F#5", "A5", "D6"]):
        mix_at(x, pluck(note(n), 1.5, 0.8, 2.5), i * 0.11, 0.6)
    for n in ["D4", "F#4", "A4", "D5", "A5"]:
        mix_at(x, pluck(note(n), 2.6, 0.7, 1.2), 0.5, 0.35)
    mix_at(x, bell(note("D6"), 2.5), 0.5, 0.3)
    return reverb(fade(x, 0, 0.3), 0.4)


def jingle_lose():
    x = silence(2.6)
    for i, n in enumerate(["A4", "G4", "E4", "D4"]):
        mix_at(x, tranh(note(n), 1.2 if i == 3 else 0.5, 1.5 if i == 3 else 0), i * 0.28, 0.6)
    mix_at(x, pad([note("D3"), note("F3"), note("A3")], 1.8), 0.84, 0.25)
    return reverb(fade(x, 0, 0.3), 0.4)


# ---------------------------------------------------------------- tiếng động: mèo

def footstep(i):
    """Đệm chân mèo trên vỉa hè: rất nhẹ, một chạm thấp + tiếng sạn nhỏ."""
    dur = 0.12
    t = t_of(dur)
    thump = np.sin(2 * np.pi * (70 + 15 * i) * t) * np.exp(-t * 60)
    grit = filt(noise(dur), "band", (1200 + 300 * i, 5000)) * np.exp(-t * (90 + 10 * i))
    return fade(thump + 0.35 * grit, 0.001, 0.02)


def jump():
    dur = 0.28
    t = t_of(dur)
    sweep = filt(noise(dur), "band", (800, 4000)) * np.sin(np.pi * t / dur) ** 2 * 0.5
    f = 320 + 380 * (t / dur)
    blip = np.sin(phase_of(f)) * np.exp(-t * 18) * 0.6
    return fade(sweep + blip)


def land():
    dur = 0.22
    t = t_of(dur)
    f = 55 + 60 * np.exp(-t * 40)
    y = np.sin(phase_of(f)) * np.exp(-t * 22) + 0.4 * filt(noise(dur), "low", 1500) * np.exp(-t * 35)
    return fade(y)


def meow(variant=0):
    """Tiếng 'meo' vui: âm nguồn răng cưa lướt cao độ, qua bộ lọc formant chuyển từ 'm' -> 'e' -> 'o'."""
    dur = 0.55 if variant == 0 else 0.4
    t = t_of(dur)
    u = t / dur
    base = 560 if variant == 0 else 700
    f0 = base * (1 + 0.35 * np.sin(np.pi * np.clip(u * 1.2, 0, 1)) - 0.12 * u)
    f0 *= 1 + 0.01 * np.sin(2 * np.pi * 6 * t)
    ph = phase_of(f0)
    src = sum(np.sin(k * ph) / k ** 0.9 for k in range(1, 16))
    # ba bộ formant cố định rồi đan chéo theo thời gian
    m = filt(src, "low", 700)
    e = filt(src, "band", (1400, 3200), 2) + 0.6 * filt(src, "band", (500, 900))
    o = filt(src, "band", (600, 1200), 2)
    w_m = np.clip(1 - u / 0.15, 0, 1)
    w_o = np.clip((u - 0.55) / 0.35, 0, 1)
    w_e = 1 - w_m - w_o
    y = m * w_m + e * np.clip(w_e, 0, 1) + o * w_o
    y *= adsr(len(t), 0.04, 0.1, 0.85, 0.15)
    return fade(y, 0.005, 0.03)


def bag_crinkle(dur=0.3, density=220):
    x = silence(dur)
    n = int(dur * density)
    for _ in range(n):
        st = rng.uniform(0, dur - 0.02)
        click = filt(noise(0.012), "band", (2000, 9000)) * np.exp(-t_of(0.012) * 300)
        mix_at(x, click, st, rng.uniform(0.2, 1.0) * np.sin(np.pi * st / dur))
    return x


def pickup():
    x = silence(0.9)
    mix_at(x, bag_crinkle(0.28), 0, 0.5)
    mix_at(x, pluck(note("A5"), 0.6, 0.8, 4), 0.12, 0.6)
    mix_at(x, pluck(note("D6"), 0.7, 0.8, 4), 0.22, 0.6)
    return reverb(fade(x, 0, 0.1), 0.2)


def deliver():
    x = silence(1.6)
    mix_at(x, bell(note("E6"), 1.2), 0, 0.6)
    mix_at(x, bell(note("A6"), 1.4), 0.13, 0.6)
    for i in range(6):
        mix_at(x, bell(note("E7") * rng.uniform(0.98, 1.3), 0.3, 6), 0.25 + i * 0.035, 0.12)
    return reverb(fade(x, 0, 0.2), 0.3)


def star(i):
    x = silence(1.0)
    mix_at(x, bell(note(["D6", "F#6", "A6"][i]), 0.9, 3), 0, 0.7)
    mix_at(x, pluck(note(["D5", "F#5", "A5"][i]), 0.6, 0.9, 5), 0, 0.3)
    return reverb(fade(x, 0, 0.1), 0.3)


def fail():
    dur = 1.3
    x = silence(dur)
    for i, (a, b) in enumerate([(392, 370), (370, 349), (349, 300)]):
        d = 0.32 if i < 2 else 0.6
        t = t_of(d)
        f = a + (b - a) * (t / d) ** 2
        f *= 1 + 0.015 * np.sin(2 * np.pi * 5.5 * t) * (i == 2)
        ph = phase_of(f)
        y = sum(np.sin(k * ph) / k for k in range(1, 10))
        y = filt(y, "low", 1400) * adsr(len(t), 0.02, 0.05, 0.8, 0.12)
        mix_at(x, y, i * 0.3, 0.5)
    return reverb(fade(x), 0.2)


def tick(urgent=False):
    dur = 0.06
    t = t_of(dur)
    f = 2300 if urgent else 1700
    y = np.sin(2 * np.pi * f * t) * np.exp(-t * 90) + 0.3 * filt(noise(dur), "high", 3000) * np.exp(-t * 200)
    if urgent:
        y = np.concatenate([y, silence(0.07), y * 0.8])
    return fade(y, 0.0005, 0.005)


# ---------------------------------------------------------------- tiếng động: Chó Mực

BARK_KIND = os.environ.get("BARK_KIND", "vua")  # "vua", "tram" (to, trầm), "kho" (khàn, gắt)


def bark(variant=0):
    """Tiếng 'gâu': mô hình nguồn-bộ lọc như giọng nói, xem bark.py."""
    y = bark_v2(BARK_KIND, seed=1 + variant)
    return fade(filt(y, "low", 7000), 0.001, 0.01)


def bark_double():
    x = silence(0.65)
    mix_at(x, bark(0), 0)
    mix_at(x, bark(1), 0.3, 0.85)
    return reverb(x, 0.2)


def growl():
    dur = 1.1
    t = t_of(dur)
    f0 = 95 * (1 + 0.06 * np.sin(2 * np.pi * 3 * t))
    ph = phase_of(f0)
    src = sum(np.sin(k * ph) / k ** 0.6 for k in range(1, 30))
    am = 0.6 + 0.4 * np.abs(np.sin(2 * np.pi * 21 * t + 3 * np.sin(2 * np.pi * 2 * t)))
    y = filt(src * am, "band", (200, 1400), 2) + 0.25 * filt(noise(dur), "band", (300, 1200)) * am
    return fade(y * adsr(len(t), 0.12, 0.2, 0.9, 0.3), 0.01, 0.1)


def bite():
    x = silence(0.4)
    w = filt(noise(0.12), "band", (600, 3000)) * np.sin(np.pi * t_of(0.12) / 0.12) ** 2
    mix_at(x, w, 0, 0.4)
    for st in (0.1, 0.135):
        t = t_of(0.05)
        c = filt(noise(0.05), "high", 2500) * np.exp(-t * 160) + np.sin(2 * np.pi * 900 * t) * np.exp(-t * 120)
        mix_at(x, c, st, 0.9)
    mix_at(x, land() * 0.6, 0.12)
    return fade(x)


# ---------------------------------------------------------------- tiếng động: giao diện

def ui_click():
    dur = 0.05
    t = t_of(dur)
    f = 1100 * np.exp(-t * 18)
    return fade(np.sin(phase_of(f)) * np.exp(-t * 70), 0.0005, 0.005)


def ui_start():
    x = silence(1.0)
    w = filt(noise(0.4), "band", (500, 5000)) * np.sin(np.pi * t_of(0.4) / 0.4) ** 3
    mix_at(x, w, 0, 0.25)
    mix_at(x, bell(note("D6"), 0.8, 3), 0.15, 0.5)
    mix_at(x, bell(note("A6"), 0.8, 3), 0.25, 0.4)
    return reverb(fade(x, 0, 0.1), 0.25)


# ---------------------------------------------------------------- tiếng động: bếp

def knead(i):
    """Nhồi bột: tiếng 'bộp' mềm, ẩm, có chút dính tay khi nhấc lên."""
    dur = 0.32
    t = t_of(dur)
    thud = np.sin(phase_of(110 + 40 * i - 50 * t)) * np.exp(-t * 25)
    squish = filt(noise(dur), "band", (250, 1400 + 200 * i)) * adsr(len(t), 0.025, 0.08, 0.3, 0.15)
    x = thud * 0.7 + squish * 0.6
    stick = filt(noise(0.06), "band", (1500, 4000)) * np.exp(-t_of(0.06) * 60)
    mix_at(x, stick, 0.2, 0.15)
    return fade(x)


def chop(i):
    """Dao chặt trên thớt gỗ: cạch sắc + tiếng gỗ trầm."""
    dur = 0.18
    t = t_of(dur)
    blade = filt(noise(dur), "high", 3000) * np.exp(-t * 180)
    wood = np.sin(2 * np.pi * (180 + 25 * i) * t) * np.exp(-t * 45) + 0.4 * np.sin(2 * np.pi * (520 + 40 * i) * t) * np.exp(-t * 70)
    return fade(blade * 0.6 + wood)


def crunch():
    """Bánh mì giòn rụm khi cắt hoặc cắn: dày đặc tiếng vỡ nhỏ."""
    x = silence(0.45)
    for _ in range(140):
        st = rng.uniform(0, 0.38)
        d = rng.uniform(0.004, 0.02)
        c = filt(noise(d), "band", (1500, rng.uniform(5000, 11000))) * np.exp(-t_of(d) * 250)
        mix_at(x, c, st, rng.uniform(0.2, 1) * np.exp(-st * 4))
    mix_at(x, filt(noise(0.2), "low", 600) * np.exp(-t_of(0.2) * 20), 0, 0.3)
    return fade(x)


def sauce():
    """Bóp chai tương/sốt: tiếng 'phụt' ướt có bọt khí."""
    dur = 0.6
    t = t_of(dur)
    f = 300 + 500 * np.sin(np.pi * t / dur)
    gurgle = np.sin(phase_of(f + 80 * np.sin(2 * np.pi * 17 * t))) * (0.5 + 0.5 * np.sin(2 * np.pi * 23 * t) ** 8)
    air = filt(noise(dur), "band", (600, 2500)) * 0.5
    y = (gurgle * 0.5 + air) * adsr(len(t), 0.03, 0.1, 0.6, 0.2)
    return fade(y)


def oven_open():
    """Mở cửa lò: bản lề kim loại kêu két rồi cửa sập xuống."""
    x = silence(0.9)
    dur = 0.45
    t = t_of(dur)
    f = 700 + 300 * np.sin(np.pi * t / dur) + 30 * np.sin(2 * np.pi * 40 * t)
    creak = np.sin(phase_of(f)) * (0.5 + 0.5 * np.sign(np.sin(2 * np.pi * 60 * t)))
    creak = filt(creak, "band", (500, 3000)) * np.sin(np.pi * t / dur)
    mix_at(x, creak, 0, 0.35)
    clunk = np.sin(2 * np.pi * 140 * t_of(0.3)) * np.exp(-t_of(0.3) * 25) + bell(620, 0.3, 12) * 0.2
    mix_at(x, clunk, 0.45, 0.8)
    return reverb(fade(x), 0.15)


def oven_ding():
    x = silence(1.8)
    mix_at(x, bell(note("C7"), 1.6, 1.6), 0, 0.8)
    return fade(x, 0, 0.2)


def wrap():
    x = silence(0.7)
    mix_at(x, bag_crinkle(0.65, 260), 0, 1)
    return fade(x)


def sizzle_loop():
    """Chiên trứng/ áp chảo: xèo liên tục, có tiếng tách lách tách. Lặp 4 giây."""
    dur = 4.0
    base = filt(noise(dur + 1), "band", (3000, 12000)) * 0.25
    base *= 0.8 + 0.2 * np.sin(2 * np.pi * 0.7 * t_of(dur + 1))
    for _ in range(260):
        st = rng.uniform(0, dur + 0.9)
        d = rng.uniform(0.003, 0.012)
        mix_at(base, filt(noise(d), "high", 2500) * np.exp(-t_of(d) * 400), st, rng.uniform(0.2, 0.9))
    return loopify(base, dur)


def oven_fire_loop():
    """Lò nướng: tiếng lửa ù trầm và lách tách gỗ/than. Lặp 4 giây."""
    dur = 4.0
    hum = filt(brown(dur + 1), "low", 300) * 1.2
    roar = filt(noise(dur + 1), "band", (200, 1200)) * 0.15 * (0.7 + 0.3 * np.sin(2 * np.pi * 0.5 * t_of(dur + 1)))
    x = hum + roar
    for _ in range(40):
        st = rng.uniform(0, dur + 0.9)
        mix_at(x, filt(noise(0.01), "band", (1000, 6000)) * np.exp(-t_of(0.01) * 300), st, rng.uniform(0.2, 0.7))
    return loopify(x, dur)


def burn():
    """Bánh cháy: tiếng xèo gắt, lách tách dày rồi phì khói."""
    dur = 1.4
    x = filt(noise(dur), "band", (2500, 9000)) * 0.3 * adsr(int(dur * SR), 0.05, 0.2, 0.7, 0.6)
    for _ in range(120):
        st = rng.uniform(0, dur - 0.05)
        d = rng.uniform(0.003, 0.015)
        mix_at(x, filt(noise(d), "high", 2000) * np.exp(-t_of(d) * 350), st, rng.uniform(0.3, 1.0) * np.exp(-st * 1.2))
    hiss = filt(noise(0.7), "band", (800, 4000)) * np.sin(np.pi * t_of(0.7) / 0.7) ** 2
    mix_at(x, hiss, 0.6, 0.5)
    return fade(x, 0.005, 0.1)


def water():
    """Rửa rau / rót nước: dòng chảy rì rào có bọt lục bục."""
    dur = 0.9
    x = filt(noise(dur), "band", (400, 3500)) * 0.35 * adsr(int(dur * SR), 0.05, 0.1, 0.8, 0.25)
    for _ in range(40):
        st = rng.uniform(0, dur - 0.08)
        d = rng.uniform(0.02, 0.05)
        t = t_of(d)
        f = rng.uniform(500, 1400) * (1 + 1.5 * t / d)  # bọt nước: tiếng 'blup' vút lên
        mix_at(x, np.sin(phase_of(f)) * np.sin(np.pi * t / d) ** 2, st, rng.uniform(0.15, 0.4))
    return fade(x, 0.01, 0.1)


def spray():
    """Bình xịt / phun hơi nước: 'xì' ngắn."""
    dur = 0.35
    t = t_of(dur)
    x = filt(noise(dur), "band", (3000, 12000)) * np.minimum(t / 0.01, 1) * np.exp(-np.maximum(t - 0.15, 0) * 20)
    return fade(x, 0.002, 0.03)


# ---------------------------------------------------------------- tiếng nền

def motorbike(dur, f_engine, direction):
    """Xe máy chạy ngang: tiếng nổ máy (xung theo nhịp đánh lửa), lớn dần rồi nhỏ dần, có Doppler."""
    t = t_of(dur)
    u = t / dur - 0.5  # 0 là lúc xe ngang người nghe
    closeness = 1 / (1 + (u * 7) ** 2)
    doppler = 1 + 0.06 * np.tanh(-u * 10)
    f = f_engine * doppler * (1 + 0.02 * np.sin(2 * np.pi * 0.7 * t))
    ph = phase_of(f)
    pulses = np.maximum(np.sin(ph), 0) ** 6
    y = filt(pulses + 0.15 * noise(dur), "band", (60, 2500 * (0.4 + 0.6 * 1)), 2)
    y = y * closeness
    y += filt(noise(dur), "band", (300, 3000)) * 0.08 * closeness  # tiếng lốp, gió
    p = np.clip(u * 3, -1, 1) * direction
    return pan(y, p)


def horn():
    """Còi xe máy 'tin tin' hai tiếng."""
    x = silence(0.6)
    for st in (0, 0.22):
        t = t_of(0.14)
        ph = 2 * np.pi * 440 * t
        sq = np.sign(np.sin(ph)) * 0.5 + np.sign(np.sin(ph * 1.26)) * 0.5
        mix_at(x, filt(sq, "band", (400, 3000)) * adsr(len(t), 0.005, 0.02, 0.8, 0.03), st)
    return x


def bird():
    x = silence(0.5)
    for k in range(rng.integers(2, 5)):
        d = rng.uniform(0.05, 0.1)
        t = t_of(d)
        f0 = rng.uniform(3000, 4500)
        f = f0 + rng.choice([-1, 1]) * 1200 * (t / d)
        mix_at(x, np.sin(phase_of(f)) * np.sin(np.pi * t / d) ** 2, k * 0.11, 0.6)
    return x


def vendor_call():
    """Tiếng rao xa xa, không lời: hai nốt luyến kiểu 'ai... ăn ...' qua formant giọng người."""
    x = silence(2.0)
    for st, (a, b), d in [(0, (330, 392), 0.55), (0.6, (392, 330), 0.9)]:
        t = t_of(d)
        f = a + (b - a) * np.clip(t / 0.25, 0, 1) ** 2
        f *= 1 + 0.012 * np.sin(2 * np.pi * 5 * t)
        ph = phase_of(f)
        src = sum(np.sin(k * ph) / k for k in range(1, 25))
        v = filt(src, "band", (600, 1100)) + 0.6 * filt(src, "band", (1000, 1400)) + 0.2 * filt(src, "band", (2400, 3000))
        mix_at(x, v * adsr(len(t), 0.06, 0.1, 0.8, 0.25), st)
    x = filt(x, "low", 2500)  # xa nên bớt sáng
    return reverb(x, 0.6, 1.3)


def street_ambience():
    dur = 40.0
    total = dur + 6
    hum = filt(brown(total), "low", 250) * 0.22
    murmur = filt(noise(total), "band", (300, 2500)) * 0.07
    murmur *= 0.7 + 0.3 * np.sin(2 * np.pi * 0.13 * t_of(total)) * np.sin(2 * np.pi * 0.31 * t_of(total))
    L = hum + murmur
    R = hum + np.roll(murmur, 3000)
    buf = stereo(L, R)

    def add(st, y, g):
        if y.ndim == 1:
            y = stereo(y, y)
        i = int(st * SR)
        n = min(len(y), len(buf) - i)
        buf[i:i + n] += y[:n] * g

    for st, d, f, dr, g in [(1, 5, 38, 1, 0.5), (7, 4, 46, -1, 0.35), (13.5, 6, 33, 1, 0.45),
                            (21, 3.5, 52, -1, 0.3), (27, 5, 40, 1, 0.5), (34, 4.5, 44, -1, 0.4)]:
        add(st, motorbike(d, f, dr), g)
    for st, p in [(9.0, -0.6), (29.5, 0.5)]:
        add(st, pan(horn(), p), 0.12)
    for st in (3.0, 3.7, 17.5, 25.0, 25.6, 37.0):
        add(st, pan(bird(), rng.uniform(-0.8, 0.8)), 0.06)
    add(15.5, pan(vendor_call(), -0.3), 0.18)
    add(32.0, pan(vendor_call(), 0.4), 0.13)
    return np.stack([loopify(buf[:, 0], dur), loopify(buf[:, 1], dur)], axis=1)


def kitchen_ambience():
    dur = 20.0
    total = dur + 2
    t = t_of(total)
    fridge = (np.sin(2 * np.pi * 50 * t) * 0.3 + np.sin(2 * np.pi * 100 * t) * 0.15) * 0.15
    room = filt(brown(total), "low", 400) * 0.25
    street = filt(noise(total), "band", (200, 1200)) * 0.03
    x = fridge + room + street
    for k in range(int(total)):  # đồng hồ treo tường
        mix_at(x, tick() * 0.05, k + 0.01)
    for st in (6.0, 15.0):  # xe máy xa ngoài đường
        mix_at(x, filt(motorbike(4, 40, 1)[:, 0], "low", 600), st, 0.25)
    y = loopify(x, dur)
    return stereo(y, np.roll(y, 1200))


# ---------------------------------------------------------------- danh sách

# ---------------------------------------------------------------- màn Thứ Hai: hẻm 42, giao bánh kiểu mới

def snore():
    """Chó Mực ngáy: hít vào khò khè (rung vòm họng ~30 Hz), thở ra phì nhẹ. Một chu kỳ 3,2 s, lặp được."""
    dur = 3.2
    x = silence(dur + 0.5)
    t = t_of(1.3)
    flutter = 0.55 + 0.45 * np.sign(np.sin(2 * np.pi * 28 * t + 2 * np.sin(2 * np.pi * 3 * t)))
    rasp = filt(noise(1.3), "band", (90, 900), 2) * flutter
    rasp += 0.6 * np.sin(phase_of(70 + 10 * np.sin(np.pi * t / 1.3))) * flutter
    mix_at(x, rasp * np.sin(np.pi * t / 1.3) ** 1.5, 0.1, 0.9)
    t2 = t_of(1.2)
    out = filt(noise(1.2), "band", (300, 2200)) * np.sin(np.pi * t2 / 1.2) ** 2
    out += 0.3 * np.sin(phase_of(900 - 300 * t2 / 1.2)) * np.sin(np.pi * t2 / 1.2) ** 3  # môi phì nhẹ
    mix_at(x, out, 1.6, 0.35)
    return loopify(x, dur)


def sniff():
    """Đánh hơi: 4 nhịp hít ngắn bằng mũi."""
    x = silence(0.9)
    for i in range(4):
        d = 0.09
        t = t_of(d)
        s = filt(noise(d), "band", (1500, 6000)) * np.sin(np.pi * t / d) ** 2
        mix_at(x, s, 0.05 + i * 0.17, 0.8 if i % 2 == 0 else 0.6)
    return fade(x)


def tag_jingle():
    """Thẻ tên bằng đồng trên vòng cổ khua vào khoen: vài tiếng 'leng keng' nhỏ, cao."""
    x = silence(0.6)
    for i in range(5):
        st = i * 0.07 + rng.uniform(0, 0.03)
        f = rng.uniform(3200, 4200)
        mix_at(x, bell(f, 0.35, 9), st, rng.uniform(0.3, 0.8))
    return fade(x, 0.001, 0.05)


def sneak_step(i):
    """Bước rón rén: đệm chân đặt từ từ, gần như chỉ có tiếng sột rất nhẹ."""
    dur = 0.18
    t = t_of(dur)
    y = filt(noise(dur), "band", (900 + 200 * i, 3500)) * np.sin(np.pi * t / dur) ** 3
    y += 0.4 * np.sin(2 * np.pi * (60 + 8 * i) * t) * np.sin(np.pi * t / dur) ** 2
    return fade(y, 0.005, 0.02)


def moto_pass(variant=0):
    """Xe máy chạy ngang qua (một lần, 3 s), có Doppler, đi từ trái sang phải hoặc ngược lại."""
    f, d = [(42, 1), (50, -1)][variant]
    return motorbike(3.0, f, d)


def moto_idle():
    """Xe máy nổ máy chờ đèn đỏ: tiếng 'bạch bạch' đều, lặp 2 giây."""
    dur = 2.0
    total = dur + 0.5
    t = t_of(total)
    f = 22 * (1 + 0.03 * np.sin(2 * np.pi * 0.8 * t))
    pulses = np.maximum(np.sin(phase_of(f)), 0) ** 10
    y = filt(pulses + 0.05 * noise(total), "band", (50, 1800), 2)
    y += 0.15 * filt(noise(total), "band", (2000, 5000)) * pulses  # tiếng lách cách máy
    return loopify(y, dur)


def basket_lower():
    """Giỏ nhựa thòng dây từ ban công: dây cót két qua lan can + giỏ lắc lư lạch cạch."""
    x = silence(1.6)
    for k in range(4):
        d = 0.18
        t = t_of(d)
        f = 1100 + 250 * np.sin(np.pi * t / d) + 40 * np.sin(2 * np.pi * 70 * t)
        creak = filt(np.sign(np.sin(phase_of(f))) * np.sin(np.pi * t / d), "band", (700, 3500))
        mix_at(x, creak, 0.05 + k * 0.32, 0.25)
    for k in range(5):
        st = 0.2 + k * 0.27 + rng.uniform(0, 0.05)
        tap = filt(noise(0.04), "band", (500, 2500)) * np.exp(-t_of(0.04) * 90)
        mix_at(x, tap, st, rng.uniform(0.3, 0.6))
    return reverb(fade(x, 0.005, 0.1), 0.15)


def basket_drop():
    """Thả bánh vào giỏ nhựa: 'bộp' giấy + giỏ nhựa rỗng kêu 'cộc'."""
    x = silence(0.5)
    mix_at(x, bag_crinkle(0.15, 200), 0, 0.5)
    t = t_of(0.2)
    hollow = np.sin(2 * np.pi * 310 * t) * np.exp(-t * 30) + 0.5 * np.sin(2 * np.pi * 760 * t) * np.exp(-t * 45)
    mix_at(x, hollow, 0.03, 0.8)
    return fade(x)


def glass_rattle():
    """Bàn bị đụng, ly cà phê rung lách cách, đá trong ly kêu."""
    x = silence(0.8)
    for k in range(9):
        st = k * 0.06 + rng.uniform(0, 0.02)
        mix_at(x, bell(rng.uniform(2200, 3000), 0.25, 14), st, 0.5 * np.exp(-k * 0.25))
    for k in range(6):
        st = rng.uniform(0, 0.5)
        mix_at(x, filt(noise(0.015), "band", (3000, 8000)) * np.exp(-t_of(0.015) * 300), st, 0.4)
    return fade(x, 0.001, 0.05)


def glass_tip():
    """Ly đổ: nghiêng 'cạch' xuống bàn, nước đá văng ra, cà phê chảy tràn."""
    x = silence(1.6)
    t = t_of(0.3)
    clunk = bell(1800, 0.3, 10) * 0.7 + np.sin(2 * np.pi * 240 * t) * np.exp(-t * 35)
    mix_at(x, clunk, 0.0, 0.8)
    for k in range(7):  # đá văng
        mix_at(x, bell(rng.uniform(2500, 4000), 0.15, 20), 0.08 + rng.uniform(0, 0.35), rng.uniform(0.2, 0.5))
    d = 0.9
    t = t_of(d)
    pour = filt(noise(d), "band", (300, 2500)) * np.sin(np.pi * np.clip(t / d, 0, 1)) ** 1.5 * 0.4
    for _ in range(15):
        st = rng.uniform(0, d - 0.05)
        dd = rng.uniform(0.02, 0.04)
        tt = t_of(dd)
        mix_at(pour, np.sin(phase_of(rng.uniform(600, 1200) * (1 + tt / dd))) * np.sin(np.pi * tt / dd) ** 2, st, 0.2)
    mix_at(x, pour, 0.25)
    return reverb(fade(x, 0.001, 0.15), 0.15)


def oil_slip():
    """Giẫm dầu trượt: tiếng 'chẹp' nhớt rồi đệm chân rít dài trên nền."""
    x = silence(0.8)
    d = 0.12
    t = t_of(d)
    squelch = filt(noise(d), "band", (300, 1500)) * np.sin(np.pi * t / d) ** 2
    squelch *= 0.6 + 0.4 * np.sin(2 * np.pi * 40 * t)
    mix_at(x, squelch, 0, 0.8)
    d = 0.55
    t = t_of(d)
    f = 1500 + 500 * np.sin(np.pi * t / d) - 600 * t / d
    squeak = np.sin(phase_of(f + 60 * np.sin(2 * np.pi * 35 * t)))
    squeak = filt(squeak + 0.3 * noise(d), "band", (800, 4000)) * np.sin(np.pi * t / d) ** 1.5
    mix_at(x, squeak, 0.08, 0.35)
    return fade(x, 0.002, 0.08)


# ---------------------------------------------------------------- Thứ Hai lượt 2: mặt đất, Cô Ba, khách, sự kiện còn thiếu

def _voice(text, speaker, mood="", wet=0.12, f0_mult=1.0):
    """Một câu nói, có chút vang phòng/phố cho khỏi khô."""
    return reverb(fade(np.concatenate([say(text, speaker, mood, f0_mult), silence(0.25)]), 0.002, 0.05), wet, 0.8)


def step_metal(i):
    """Chân mèo trên mái tôn: chạm nhẹ nhưng tôn rung 'boong' trầm, vài họa âm lệch."""
    dur = 0.32
    t = t_of(dur)
    y = np.sin(2 * np.pi * (75 + 10 * i) * t) * np.exp(-t * 55)
    for f, a, d in [(190, 0.5, 18), (430, 0.35, 22), (760, 0.25, 28), (1240, 0.15, 35), (2050, 0.08, 45)]:
        y += a * np.sin(2 * np.pi * f * (1 + 0.03 * i) * t + rng.uniform(0, 6)) * np.exp(-t * d)
    y += 0.25 * filt(noise(dur), "band", (1500, 6000)) * np.exp(-t * 120)
    return fade(y, 0.001, 0.05)


def step_wood(i):
    """Trên thùng gỗ, ghế, ổ chó: tiếng 'cộc' rỗng."""
    dur = 0.15
    t = t_of(dur)
    y = np.sin(2 * np.pi * (150 + 20 * i) * t) * np.exp(-t * 40) + 0.5 * np.sin(2 * np.pi * (390 + 35 * i) * t) * np.exp(-t * 60)
    y += 0.3 * filt(noise(dur), "band", (800, 4000)) * np.exp(-t * 150)
    return fade(y, 0.001, 0.02)


def step_grass(i):
    """Trên cỏ công viên: sột nhẹ, gần như không có tiếng chạm."""
    dur = 0.16
    t = t_of(dur)
    sw = filt(noise(dur), "band", (2200 + 300 * i, 8000)) * np.sin(np.pi * t / dur) ** 2
    y = 0.6 * sw + 0.3 * np.sin(2 * np.pi * 60 * t) * np.exp(-t * 70)
    return fade(y, 0.002, 0.03)


def splash():
    """Tờ báo rơi tõm xuống vũng nước: tạt nước + vài bọt nổi lên."""
    x = silence(0.8)
    t = t_of(0.3)
    mix_at(x, filt(noise(0.3), "band", (400, 5000)) * np.exp(-t * 14), 0, 0.8)
    mix_at(x, np.sin(2 * np.pi * 90 * t) * np.exp(-t * 30), 0, 0.5)
    for _ in range(9):
        d = rng.uniform(0.02, 0.05)
        tt = t_of(d)
        f = rng.uniform(500, 1300) * (1 + 1.5 * tt / d)
        mix_at(x, np.sin(phase_of(f)) * np.sin(np.pi * tt / d), rng.uniform(0.05, 0.5), rng.uniform(0.1, 0.3))
    return reverb(fade(x), 0.15)


def stamp():
    """Tem Cô Ba: con dấu đóng 'cộp' lên giấy rồi lấp lánh hai nốt."""
    x = silence(1.1)
    t = t_of(0.2)
    mix_at(x, np.sin(phase_of(110 + 80 * np.exp(-t * 40))) * np.exp(-t * 25), 0, 0.9)
    mix_at(x, filt(noise(0.2), "band", (600, 4000)) * np.exp(-t * 60), 0, 0.4)
    mix_at(x, bell(note("G6"), 0.7, 4), 0.12, 0.35)
    mix_at(x, bell(note("D7"), 0.8, 4), 0.2, 0.3)
    for k in range(5):
        mix_at(x, bell(note("G7") * rng.uniform(0.97, 1.2), 0.25, 8), 0.26 + k * 0.04, 0.06)
    return reverb(fade(x, 0, 0.2), 0.25)


def coin():
    """Tiền boa: hai đồng xu chạm nhau 'keng keng'."""
    x = silence(0.8)
    for st, g in [(0, 1.0), (0.09, 0.7), (0.16, 0.35)]:
        t = t_of(0.5)
        y = sum(a * np.sin(2 * np.pi * f * rng.uniform(0.99, 1.01) * t) * np.exp(-t * d)
                for f, a, d in [(2350, 1, 9), (5900, 0.6, 14), (8200, 0.35, 20), (3700, 0.4, 12)])
        mix_at(x, y, st, g)
    return reverb(fade(x, 0, 0.1), 0.15)


def record():
    """Kỷ lục mới: bốn nốt marimba đi lên + chuông."""
    x = silence(1.4)
    for k, n in enumerate(["C6", "E6", "G6", "C7"]):
        mix_at(x, marimba(note(n), 0.5), k * 0.08, 0.6)
    mix_at(x, bell(note("C7"), 1.0), 0.32, 0.4)
    return reverb(fade(x, 0, 0.2), 0.3)


def bike_hit():
    """Xe máy thắng gấp rít lên rồi chạm Bơ 'bịch', đồ nhựa trên xe khua lạch cạch."""
    x = silence(0.9)
    d = 0.45
    t = t_of(d)
    f = 2300 * (1 + 0.04 * np.sin(2 * np.pi * 37 * t)) * (1 - 0.15 * t / d)
    sq = np.sin(phase_of(f)) + 0.4 * np.sin(phase_of(f * 2.01))
    mix_at(x, (sq * 0.35 + filt(noise(d), "band", (1500, 5000)) * 0.5) * adsr(len(t), 0.02, 0.05, 0.8, 0.12), 0, 0.6)
    tt = t_of(0.25)
    mix_at(x, np.sin(phase_of(70 + 60 * np.exp(-tt * 30))) * np.exp(-tt * 18), 0.36, 0.9)
    for k in range(5):
        mix_at(x, filt(noise(0.02), "band", (1500, 6000)) * np.exp(-t_of(0.02) * 200), 0.4 + k * rng.uniform(0.03, 0.07), 0.3)
    return fade(x, 0, 0.1)


def meow_startle():
    """Bơ giật mình: 'mééo!' cao, gắt, ngắn."""
    dur = 0.32
    t = t_of(dur)
    u = t / dur
    f0 = 820 * (1 + 0.5 * np.sin(np.pi * np.clip(u * 1.6, 0, 1))) * (1 + 0.03 * rng.standard_normal(len(t)).cumsum() / 300)
    ph = phase_of(f0)
    src = sum(np.sin(k * ph) / k ** 0.8 for k in range(1, 14))
    y = filt(src, "band", (1300, 3600), 2) + 0.5 * filt(src, "band", (600, 1000))
    y += 0.15 * filt(noise(dur), "band", (2000, 6000))  # chút khàn
    y *= adsr(len(t), 0.015, 0.05, 0.8, 0.1)
    return fade(y, 0.003, 0.03)


def squish():
    """Bánh bị dập khi rơi cao: giấy bẹp + vỏ bánh vỡ vụn, nghe hơi buồn."""
    x = silence(0.6)
    t = t_of(0.25)
    mix_at(x, filt(noise(0.25), "low", 900) * np.exp(-t * 15), 0, 0.6)
    for _ in range(50):
        st = rng.uniform(0, 0.25)
        dd = rng.uniform(0.004, 0.015)
        mix_at(x, filt(noise(dd), "band", (1200, 6000)) * np.exp(-t_of(dd) * 300), st, rng.uniform(0.1, 0.5) * np.exp(-st * 8))
    tt = t_of(0.3)
    mix_at(x, np.sin(phase_of(330 - 120 * tt / 0.3)) * np.exp(-tt * 8) * 0.25, 0.2)
    return fade(x)


def paper_slip():
    """Cô Ba đưa phiếu đơn: tờ giấy phẩy 'soạt'."""
    d = 0.22
    t = t_of(d)
    y = filt(noise(d), "band", (1800, 9000)) * np.sin(np.pi * t / d) ** 1.5
    mix_at(y, bag_crinkle(0.12, 150), 0.08, 0.4)
    return fade(y)


def street_morning():
    """Phố buổi sáng Thứ Hai: chim sẻ ríu rít nhiều hơn, chổi tre quét vỉa hè, gà gáy xa,
    ít xe hơn buổi trưa, xa xa có tiếng rao bánh mì."""
    dur = 40.0
    total = dur + 6
    hum = filt(brown(total), "low", 220) * 0.16
    murmur = filt(noise(total), "band", (300, 2500)) * 0.04
    buf = stereo(hum + murmur, hum + np.roll(murmur, 4000))

    def add(st, y, g):
        if y.ndim == 1:
            y = stereo(y, y)
        i = int(st * SR)
        n = min(len(y), len(buf) - i)
        buf[i:i + n] += y[:n] * g

    for st, d, f, dr, g in [(4, 5, 40, 1, 0.35), (18, 4, 47, -1, 0.25), (31, 5, 36, 1, 0.3)]:
        add(st, motorbike(d, f, dr), g)
    # chim sẻ: từng đàn nhỏ ríu rít
    for _ in range(26):
        st = rng.uniform(0, dur)
        p = rng.uniform(-0.9, 0.9)
        for k in range(rng.integers(1, 4)):
            add(st + k * rng.uniform(0.2, 0.5), pan(bird(), p), rng.uniform(0.04, 0.08))
    # chổi tre quét: hai đợt, mỗi nhát 'xoẹt' dài
    for st0, p in [(2.0, -0.5), (22.0, 0.6)]:
        for k in range(9):
            d = rng.uniform(0.45, 0.6)
            t = t_of(d)
            sw = filt(noise(d), "band", (1500, 7000)) * np.sin(np.pi * t / d) ** 2
            add(st0 + k * 0.85, pan(sw, p), 0.06)
    # gà gáy xa: một tiếng 'ò ó o' luyến
    t = t_of(1.4)
    f = np.interp(t, [0, 0.2, 0.5, 0.9, 1.4], [500, 700, 650, 780, 520])
    ph = phase_of(f)
    src = sum(np.sin(k * ph) / k for k in range(1, 18))
    rooster = (filt(src, "band", (800, 1800)) + 0.5 * filt(src, "band", (2000, 3000))) * adsr(len(t), 0.05, 0.1, 0.8, 0.3)
    add(12.0, pan(filt(reverb(rooster, 0.6, 1.4), "low", 2200), 0.7), 0.05)
    # rao bánh mì xa
    call = filt(reverb(say("Bánh mì nóng giòn đây!", "ban_hang"), 0.7, 1.4), "low", 2400)
    add(27.0, pan(call, -0.4), 0.07)
    add(8.5, pan(horn(), 0.5), 0.07)
    return np.stack([loopify(buf[:, 0], dur), loopify(buf[:, 1], dur)], axis=1)


# ---------------------------------------------------------------- Thứ Ba: chợ sáng, góc cờ tướng, tạp hóa

def scale_clank():
    """Cân đĩa ở sạp chợ: đĩa nhôm 'keng' rồi lò xo rung 'boing' nhỏ."""
    x = silence(0.9)
    t = t_of(0.6)
    y = sum(a * np.sin(2 * np.pi * f * t) * np.exp(-t * d) for f, a, d in [(620, 1, 8), (1530, 0.6, 12), (2810, 0.4, 16), (4100, 0.2, 22)])
    mix_at(x, y, 0, 0.7)
    mix_at(x, filt(noise(0.05), "band", (1000, 5000)) * np.exp(-t_of(0.05) * 80), 0, 0.4)
    tt = t_of(0.5)
    mix_at(x, np.sin(phase_of(140 + 30 * np.sin(2 * np.pi * 9 * tt))) * np.exp(-tt * 9) * 0.3, 0.05)
    return reverb(fade(x, 0, 0.1), 0.15)


def chess_slap(i):
    """Quân cờ tướng gỗ đập xuống bàn đá: 'cạch' sắc, gọn, có tiếng bàn dội."""
    dur = 0.25
    t = t_of(dur)
    click = filt(noise(dur), "high", 2500) * np.exp(-t * 400)
    body = np.sin(2 * np.pi * (1050 + 90 * i) * t) * np.exp(-t * 90) + 0.5 * np.sin(2 * np.pi * (2400 + 150 * i) * t) * np.exp(-t * 140)
    table = np.sin(2 * np.pi * (210 + 15 * i) * t) * np.exp(-t * 35)
    return reverb(fade(click * 0.9 + body * 0.6 + table * 0.5, 0.0005, 0.03), 0.12)


def chess_rattle():
    """Bàn bị đụng: quân cờ nảy lộp cộp, vài quân lăn, một quân rớt xuống đất."""
    x = silence(1.3)
    t = t_of(0.2)
    mix_at(x, np.sin(2 * np.pi * 120 * t) * np.exp(-t * 30), 0, 0.8)  # cú đụng bàn
    for _ in range(26):
        st = rng.uniform(0.01, 0.55) ** 1.3
        d = 0.04
        tt = t_of(d)
        c = np.sin(2 * np.pi * rng.uniform(900, 1600) * tt) * np.exp(-tt * 120) + filt(noise(d), "high", 3000) * np.exp(-tt * 400)
        mix_at(x, c, st, rng.uniform(0.15, 0.5))
    for k, st in enumerate((0.75, 0.9, 0.98)):  # quân rớt nảy trên nền gạch
        mix_at(x, chess_slap(k) * 0.5 * 0.6 ** k, st)
    return fade(x, 0, 0.1)


def shush():
    """'Suỵt!': hơi xì qua môi tròn, kết bằng 't' bật nhẹ."""
    d = 0.6
    t = t_of(d)
    s = filt(noise(d), "band", (2200, 7000)) * adsr(len(t), 0.06, 0.1, 0.85, 0.12)
    s += 0.5 * filt(noise(d), "band", (1500, 3000)) * adsr(len(t), 0.15, 0.1, 0.6, 0.1)  # môi chúm lại
    x = np.concatenate([s, silence(0.04), filt(noise(0.015), "band", (3000, 8000)) * np.exp(-t_of(0.015) * 300) * 0.5, silence(0.2)])
    return reverb(fade(x), 0.1)


def check_cheer():
    """'Chiếu tướng!': ông đánh cờ hô to, người đứng xem 'ồ' lên rồi vỗ tay."""
    x = silence(2.6)
    mix_at(x, say("Chiếu tướng!", "ong_tam", "gat"), 0, 0.9)
    for k, spk in enumerate(["khach_nam", "chu_tu", "khach_nu", "anh_hung", "khach_nam"]):
        mix_at(x, say("Ồ!", spk, "vui", f0_mult=rng.uniform(0.95, 1.1)), 0.55 + k * rng.uniform(0.02, 0.06), 0.35)
    for _ in range(70):  # vỗ tay
        st = rng.uniform(0.9, 2.2)
        d = 0.03
        c = filt(noise(d), "band", (700, rng.uniform(2500, 5000))) * np.exp(-t_of(d) * 160)
        mix_at(x, c, st, rng.uniform(0.15, 0.4) * (1 - (st - 0.9) / 1.6))
    return reverb(fade(x, 0, 0.3), 0.25, 1.1)


def egg_crack():
    """Một quả trứng vỡ trong túi: vỏ nứt 'rắc' rồi lòng trứng 'bẹp' ướt."""
    x = silence(0.7)
    for _ in range(14):
        st = rng.uniform(0, 0.06)
        d = rng.uniform(0.003, 0.01)
        mix_at(x, filt(noise(d), "band", (2500, 9000)) * np.exp(-t_of(d) * 500), st, rng.uniform(0.4, 1))
    t = t_of(0.3)
    wet = filt(noise(0.3), "band", (300, 1800)) * np.exp(-t * 18) * (1 + 0.5 * np.sin(2 * np.pi * 25 * t))
    mix_at(x, wet, 0.05, 0.6)
    tt = t_of(0.2)
    mix_at(x, np.sin(phase_of(260 - 120 * tt / 0.2)) * np.exp(-tt * 20), 0.07, 0.3)
    mix_at(x, bag_crinkle(0.2, 160), 0.02, 0.25)
    return fade(x)


def nylon(i):
    """Túi nilon sột soạt khi Bơ ngậm túi chạy: lạo xạo mỏng, sáng hơn túi giấy."""
    d = 0.25 + 0.06 * i
    x = silence(d)
    for _ in range(int(d * 320)):
        st = rng.uniform(0, d - 0.015)
        c = filt(noise(0.008), "band", (3500, 12000)) * np.exp(-t_of(0.008) * 450)
        mix_at(x, c, st, rng.uniform(0.2, 1.0) * np.sin(np.pi * st / d) ** 0.8)
    x += 0.15 * filt(noise(d), "band", (4000, 10000)) * np.sin(np.pi * t_of(d) / d)
    return fade(x)


def cart_rattle():
    """Xe đẩy hàng rong lăn trên đường: bánh sắt lộc cộc theo vòng, đồ trên xe khua lạch cạch. Lặp 2 s."""
    dur = 2.0
    x = silence(dur + 0.3)
    t = t_of(dur + 0.3)
    x += filt(noise(dur + 0.3), "low", 300) * 0.35 * (1 + 0.3 * np.sin(2 * np.pi * 3 * t))  # lăn ù ù
    period = 0.25  # một vòng bánh có chỗ móp
    k = 0.0
    while k < dur + 0.2:
        tt = t_of(0.08)
        mix_at(x, np.sin(2 * np.pi * rng.uniform(160, 220) * tt) * np.exp(-tt * 50), k, 0.5)
        k += period * rng.uniform(0.95, 1.05)
    for _ in range(36):  # nồi, rổ, chai lọ trên xe
        st = rng.uniform(0, dur + 0.2)
        d = 0.06
        tt = t_of(d)
        f = rng.uniform(700, 2600)
        c = np.sin(2 * np.pi * f * tt) * np.exp(-tt * 70) + 0.4 * np.sin(2 * np.pi * f * 2.7 * tt) * np.exp(-tt * 110)
        mix_at(x, c, st, rng.uniform(0.08, 0.3))
    return loopify(x, dur)


def cart_bump():
    """Bơ (hoặc người) đụng xe đẩy: 'cộp' + đồ trên xe khua."""
    x = silence(0.8)
    t = t_of(0.25)
    mix_at(x, np.sin(phase_of(95 + 50 * np.exp(-t * 30))) * np.exp(-t * 20), 0, 0.9)
    for _ in range(14):
        st = rng.uniform(0.01, 0.45)
        d = 0.06
        tt = t_of(d)
        f = rng.uniform(700, 2600)
        mix_at(x, np.sin(2 * np.pi * f * tt) * np.exp(-tt * 70), st, rng.uniform(0.1, 0.4) * np.exp(-st * 4))
    return fade(x)


def basket_topple():
    """Thúng tre đổ: nan tre răng rắc, thúng 'bộp' xuống đất, rau củ lăn lộp bộp."""
    x = silence(1.4)
    for _ in range(40):
        st = rng.uniform(0, 0.25)
        d = rng.uniform(0.005, 0.02)
        mix_at(x, filt(noise(d), "band", (1200, 5000)) * np.exp(-t_of(d) * 250), st, rng.uniform(0.2, 0.6))
    t = t_of(0.3)
    mix_at(x, np.sin(phase_of(80 + 40 * np.exp(-t * 25))) * np.exp(-t * 14) + 0.3 * filt(noise(0.3), "low", 1200) * np.exp(-t * 20), 0.22, 0.9)
    for _ in range(9):
        st = rng.uniform(0.3, 1.1)
        tt = t_of(0.1)
        mix_at(x, np.sin(2 * np.pi * rng.uniform(140, 260) * tt) * np.exp(-tt * 40), st, rng.uniform(0.15, 0.4) * (1.2 - st))
    return fade(x, 0, 0.15)


# ---------------------------------------------------------------- chim (luồng "Bồ câu và chim")

def bird_whistle(f0, f1, dur, vib=0.0):
    """Một tiếng huýt chim: sóng sin quét cao độ f0 -> f1, có rung nhẹ, lên nhanh tắt nhanh."""
    t = t_of(dur)
    k = t / dur
    f = f0 + (f1 - f0) * (3 * k * k - 2 * k * k * k) + vib * np.sin(2 * np.pi * 38 * t)
    x = np.sin(2 * np.pi * np.cumsum(f) / SR) + 0.12 * np.sin(4 * np.pi * np.cumsum(f) / SR)
    env = np.minimum(1.0, t / 0.008) * np.minimum(1.0, (dur - t) / 0.02)
    return x * np.clip(env, 0, 1)


def chao_mao_hot():
    """Chào mào hót: một chuỗi 'líu lo' 5–6 nốt huýt quét lên xuống quanh 2–4 kHz, nốt cuối kéo dài."""
    x = silence(1.5)
    notes = [(2400, 3300, 0.09), (3300, 2600, 0.08), (2600, 3600, 0.1), (3500, 2900, 0.07), (2200, 3100, 0.12),
        (3100, 2500, 0.26)]
    st = 0.02
    for f0, f1, d in notes:
        j = rng.uniform(0.94, 1.06)
        mix_at(x, bird_whistle(f0 * j, f1 * j, d, vib=60.0), st, rng.uniform(0.7, 1.0))
        st += d + rng.uniform(0.03, 0.07)
    return fade(reverb(x, wet=0.12, size=0.4), 0, 0.1)


def chao_mao_chiep():
    """Chào mào kêu khẽ một tiếng 'chiếp' khi nhảy trong lồng."""
    x = silence(0.25)
    mix_at(x, bird_whistle(3400, 2700, 0.06), 0.01, 1.0)
    mix_at(x, bird_whistle(3000, 3500, 0.05), 0.1, 0.7)
    return fade(x, 0, 0.05)


def build_voice_jobs():
    """Mọi câu nói trong game. Muốn đổi lời: sửa chữ ở đây rồi chạy lại file đó."""
    lines = {
        # Cô Ba, khách cảm ơn, hai ông đánh cờ mắng: nay nói bằng giọng ú ớ trong game (scripts/giong_uo.gd)
        # Thứ Ba: người đi chợ bị đụng
        "oops_1": ("Ối!", "khach_nu", "gat"),
        "oops_2": ("Ui cha!", "khach_nam", "gat"),
    }
    return {name: ((lambda t=t, s=s, m=m: _voice(t, s, m)), "ogg") for name, (t, s, m) in lines.items()}  # câu nói dài, .ogg cho nhẹ


def market_ambience():
    """Chợ sáng Thứ Ba: rì rầm người mua bán (nhiều giọng nói khẽ chồng lên nhau), rao hàng,
    cân đĩa, túi nilon, dao chặt thớt, xe máy xa. 40 s lặp liền."""
    dur = 40.0
    total = dur + 6
    hum = filt(brown(total), "low", 220) * 0.12
    buf = stereo(hum, hum)

    def add(st, y, g):
        if y.ndim == 1:
            y = stereo(y, y)
        i = int(st * SR)
        n = min(len(y), len(buf) - i)
        buf[i:i + n] += y[:n] * g

    chatter = ["Bao nhiêu một ký?", "Bớt chút đi chị.", "Lấy thêm bó rau nha.", "Hôm nay cá tươi lắm.",
               "Mua gì đi cô ơi.", "Trứng gà ta đó.", "Thôi được, lấy đi.", "Cho xin cọng hành.",
               "Mai ghé nữa nha.", "Ừ, để đó đi.", "Ủa, sao mắc vậy?", "Chừng nhiêu tiền?"]
    speakers = ["khach_nu", "khach_nam", "ban_hang", "coba", "chi_may", "chu_tu", "ba_sau"]
    for k in range(48):  # rì rầm: câu ngắn, nhỏ, xa, đủ hướng
        line = say(chatter[k % len(chatter)], speakers[rng.integers(len(speakers))], "", rng.uniform(0.92, 1.1))
        line = filt(line, "low", rng.uniform(1800, 3200))
        add(rng.uniform(0, dur), pan(line, rng.uniform(-0.9, 0.9)), rng.uniform(0.03, 0.07))
    for st, text, p in [(3.0, "Rau tươi đây!", -0.6), (14.0, "Cá tươi nè, cá tươi!", 0.5),
                        (24.5, "Bánh bao nóng đây!", -0.2), (34.0, "Mua gì đi cô ơi!", 0.7)]:
        add(st, pan(reverb(say(text, "ban_hang", "vui", rng.uniform(0.95, 1.1)), 0.5, 1.2), p), 0.13)
    for st in rng.uniform(0, dur, 7):
        add(st, pan(scale_clank(), rng.uniform(-0.7, 0.7)), 0.12)
    for st in rng.uniform(0, dur, 9):
        add(st, pan(nylon(rng.integers(3)), rng.uniform(-0.8, 0.8)), 0.06)
    for st0 in (9.0, 29.0):  # sạp thịt chặt thớt
        for k in range(6):
            add(st0 + k * 0.35, pan(chop(k % 3), 0.35), 0.12)
    for st, d, f, dr, g in [(6, 5, 38, 1, 0.18), (20, 4, 46, -1, 0.14), (36, 4, 40, 1, 0.16)]:
        add(st, motorbike(d, f, dr), g)
    return np.stack([loopify(buf[:, 0], dur), loopify(buf[:, 1], dur)], axis=1)


def build():
    jobs = {
        # nhạc nền (lặp)
        "music_menu": (music_menu, "ogg"),
        "music_delivery": (music_delivery, "ogg"),
        "music_chase": (music_chase, "ogg"),
        "music_kitchen": (music_kitchen, "ogg"),
        "jingle_win": (jingle_win, "ogg"),
        "jingle_lose": (jingle_lose, "ogg"),
        # tiếng nền (lặp)
        "amb_street": (street_ambience, "ogg"),
        "amb_kitchen": (kitchen_ambience, "ogg"),
        # mèo
        "step_1": (lambda: footstep(0), "wav"),
        "step_2": (lambda: footstep(1), "wav"),
        "step_3": (lambda: footstep(2), "wav"),
        "step_4": (lambda: footstep(3), "wav"),
        "jump": (jump, "wav"),
        "land": (land, "wav"),
        "meow": (lambda: meow(0), "wav"),
        "meow_short": (lambda: meow(1), "wav"),
        # đơn hàng
        "pickup": (pickup, "wav"),
        "deliver": (deliver, "wav"),
        "star_1": (lambda: star(0), "wav"),
        "star_2": (lambda: star(1), "wav"),
        "star_3": (lambda: star(2), "wav"),
        "fail": (fail, "wav"),
        "tick": (tick, "wav"),
        "tick_urgent": (lambda: tick(True), "wav"),
        # Chó Mực
        "bark": (bark_double, "wav"),
        "bark_single": (lambda: reverb(fade(np.concatenate([bark(0), silence(0.3)])), 0.2), "wav"),
        "growl": (growl, "wav"),
        "bite": (bite, "wav"),
        # giao diện
        "ui_click": (ui_click, "wav"),
        "ui_start": (ui_start, "wav"),
        # bếp
        "knead_1": (lambda: knead(0), "wav"),
        "knead_2": (lambda: knead(1), "wav"),
        "knead_3": (lambda: knead(2), "wav"),
        "chop_1": (lambda: chop(0), "wav"),
        "chop_2": (lambda: chop(1), "wav"),
        "chop_3": (lambda: chop(2), "wav"),
        "crunch": (crunch, "wav"),
        "sauce": (sauce, "wav"),
        "oven_open": (oven_open, "wav"),
        "oven_ding": (oven_ding, "wav"),
        "wrap": (wrap, "wav"),
        "burn": (burn, "wav"),
        "water": (water, "wav"),
        "spray": (spray, "wav"),
        # màn Thứ Hai
        "snore": (snore, "ogg"),
        "sniff": (sniff, "wav"),
        "tag_jingle": (tag_jingle, "wav"),
        "sneak_1": (lambda: sneak_step(0), "wav"),
        "sneak_2": (lambda: sneak_step(1), "wav"),
        "sneak_3": (lambda: sneak_step(2), "wav"),
        "moto_pass_1": (lambda: moto_pass(0), "ogg"),
        "moto_pass_2": (lambda: moto_pass(1), "ogg"),
        "moto_idle": (moto_idle, "ogg"),
        "horn": (lambda: pan(horn(), 0.0)[:, 0], "wav"),
        "basket_lower": (basket_lower, "wav"),
        "basket_drop": (basket_drop, "wav"),
        "glass_rattle": (glass_rattle, "wav"),
        "glass_tip": (glass_tip, "wav"),
        "oil_slip": (oil_slip, "wav"),
        "sizzle": (sizzle_loop, "ogg"),
        "oven_fire": (oven_fire_loop, "ogg"),
        # Thứ Hai lượt 2
        "amb_morning": (street_morning, "ogg"),
        "step_metal_1": (lambda: step_metal(0), "wav"),
        "step_metal_2": (lambda: step_metal(1), "wav"),
        "step_metal_3": (lambda: step_metal(2), "wav"),
        "step_wood_1": (lambda: step_wood(0), "wav"),
        "step_wood_2": (lambda: step_wood(1), "wav"),
        "step_wood_3": (lambda: step_wood(2), "wav"),
        "step_grass_1": (lambda: step_grass(0), "wav"),
        "step_grass_2": (lambda: step_grass(1), "wav"),
        "step_grass_3": (lambda: step_grass(2), "wav"),
        "splash": (splash, "wav"),
        "stamp": (stamp, "wav"),
        "coin": (coin, "wav"),
        "record": (record, "wav"),
        "bike_hit": (bike_hit, "wav"),
        "meow_startle": (meow_startle, "wav"),
        "squish": (squish, "wav"),
        "paper_slip": (paper_slip, "wav"),
        # Thứ Ba
        "amb_market": (market_ambience, "ogg"),
        "scale_clank": (scale_clank, "wav"),
        "chess_slap_1": (lambda: chess_slap(0), "wav"),
        "chess_slap_2": (lambda: chess_slap(1), "wav"),
        "chess_slap_3": (lambda: chess_slap(2), "wav"),
        "chess_rattle": (chess_rattle, "wav"),
        "shush": (shush, "wav"),
        "check_cheer": (check_cheer, "ogg"),
        "egg_crack": (egg_crack, "wav"),
        "nylon_1": (lambda: nylon(0), "wav"),
        "nylon_2": (lambda: nylon(1), "wav"),
        "nylon_3": (lambda: nylon(2), "wav"),
        "cart_rattle": (cart_rattle, "ogg"),
        "cart_bump": (cart_bump, "wav"),
        "basket_topple": (basket_topple, "wav"),
        # Chim chào mào (K3 góc cờ, K4 lồng ban công)
        "chao_mao_hot": (chao_mao_hot, "wav"),
        "chao_mao_chiep": (chao_mao_chiep, "wav"),
    }
    jobs.update(build_voice_jobs())  # Cô Ba, khách, hai ông đánh cờ
    global rng
    only = sys.argv[1:]
    for name, (fn, kind) in jobs.items():
        if only and name not in only:
            continue
        rng = np.random.default_rng(zlib.crc32(name.encode()))  # mỗi file một hạt riêng: làm lại file nào cũng ra y hệt
        x = fn()
        loud = {"music": 0.8, "amb": 0.7, "jingle": 0.85}
        peak = next((v for k, v in loud.items() if name.startswith(k)), 0.89)
        save(name, x, kind, peak, q=4 if name.startswith(("music", "amb")) else 5)


if __name__ == "__main__":
    build()
