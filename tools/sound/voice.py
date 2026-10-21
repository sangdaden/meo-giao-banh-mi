"""Giọng người tổng hợp cho game (Cô Ba, khách, hai ông đánh cờ, người bán ở chợ).

Cách làm giống bark.py: nguồn xung thanh môn qua bộ lọc formant, nhưng điều khiển bằng
chữ quốc ngữ. say("Bơ ơi, đi giao bánh nè!", "coba") tự tách từng tiếng thành phụ âm
đầu, nguyên âm, phụ âm cuối và thanh điệu:

- Thanh điệu quyết định đường cao độ: ngang phẳng, huyền đi xuống, sắc vút lên, hỏi
  xuống rồi lên, ngã gãy giữa rồi vút, nặng rơi gắt và tắt ở cổ họng.
- Nguyên âm cho ba formant F1-F3 (bảng VOWELS, giọng nam người lớn); giọng nữ, trẻ em
  nhân lên theo hệ số của người nói. Vần có nhiều nguyên âm ("ao", "ươi") thì formant
  lướt từ âm này sang âm kia.
- Phụ âm đầu là tiếng nổ, tiếng xì hoặc tiếng mũi ngắn trước nguyên âm; phụ âm cuối
  m/n/ng/nh khép thành tiếng mũi, t/c/p/ch thì tắt gọn.

Nghe ra giọng nói tiếng Việt có ngữ điệu, đủ để hiểu ý (chào, cảm ơn, mắng, reo),
không nhằm rõ từng chữ như máy đọc.
"""
import unicodedata
import zlib

import numpy as np
from scipy.signal import butter, sosfilt

from bark import SR, formant_filter, glottal_source

VOWELS = {
    "a": (760, 1260, 2550), "ă": (720, 1300, 2550), "â": (560, 1350, 2500), "ơ": (520, 1360, 2500),
    "e": (580, 1850, 2600), "ê": (430, 2080, 2700), "i": (300, 2250, 3000), "y": (300, 2250, 3000),
    "o": (540, 900, 2450), "ô": (430, 820, 2400), "u": (330, 760, 2350), "ư": (360, 1350, 2400),
}
NASAL = (260, 1100, 2300)
# Đường cao độ của sáu thanh (nửa cung so với giọng gốc) tại đầu, giữa, cuối tiếng
TONES = {
    "ngang": (0.0, 0.0, -0.6), "huyen": (-1.5, -3.5, -5.5), "sac": (0.0, 1.8, 5.5),
    "hoi": (-1.0, -4.5, -0.5), "nga": (0.5, -1.5, 6.0), "nang": (-1.5, -4.0, -8.0),
}
MARKS = {"̀": "huyen", "́": "sac", "̉": "hoi", "̃": "nga", "̣": "nang"}
ONSETS = ["ngh", "ng", "nh", "ch", "tr", "th", "kh", "ph", "gh", "gi", "qu",
          "b", "c", "d", "đ", "g", "h", "k", "l", "m", "n", "p", "r", "s", "t", "v", "x"]
CODAS = ["ng", "nh", "ch", "c", "m", "n", "p", "t"]

# f0 gốc, hệ số formant, độ khàn, tốc độ nói (1 = bình thường)
SPEAKERS = {
    "coba": dict(f0=215, F=1.13, rough=0.08, rate=1.0),
    "be_na": dict(f0=330, F=1.3, rough=0.03, rate=1.1),
    "chi_may": dict(f0=240, F=1.16, rough=0.04, rate=1.05),
    "chu_tu": dict(f0=118, F=1.0, rough=0.12, rate=0.95),
    "anh_hung": dict(f0=135, F=1.03, rough=0.08, rate=1.05),
    "ba_sau": dict(f0=195, F=1.08, rough=0.22, rate=0.82),
    "ong_bay": dict(f0=108, F=0.96, rough=0.3, rate=0.95),
    "ong_tam": dict(f0=132, F=0.99, rough=0.25, rate=1.05),
    "ban_hang": dict(f0=255, F=1.15, rough=0.1, rate=1.0),
    "khach_nam": dict(f0=125, F=1.0, rough=0.1, rate=1.0),
    "khach_nu": dict(f0=225, F=1.14, rough=0.06, rate=1.0),
}


def _sos(kind, f, order=2):
    return butter(order, np.array(f) / (SR / 2), btype=kind, output="sos")


def parse(word):
    """'bánh' -> ('b', 'a', 'nh', 'sac')."""
    d = unicodedata.normalize("NFD", word.lower())
    tone = "ngang"
    for m, t in MARKS.items():
        if m in d:
            tone = t
            d = d.replace(m, "")
    w = unicodedata.normalize("NFC", d)
    onset = next((o for o in ONSETS if w.startswith(o) and len(w) > len(o)), "")
    rest = w[len(onset):]
    if onset == "gi" and rest[:1] not in VOWELS:
        onset, rest = "d", "i" + rest   # "gì" = d + i
    coda = next((c for c in CODAS if rest.endswith(c) and len(rest) > len(c)), "")
    nucleus = rest[:len(rest) - len(coda)] if coda else rest
    if onset == "qu":
        nucleus = "u" + nucleus
    nucleus = "".join(ch for ch in nucleus if ch in VOWELS) or "ơ"
    return onset, nucleus, coda, tone


def _formant_path(nucleus, coda, n, scale):
    """Ba đường formant theo mẫu: nguyên âm chính giữ lâu, lướt sang âm sau, khép về phụ âm cuối."""
    pts = [VOWELS[c] for c in nucleus]
    # Âm lướt đầu (u, i trước nguyên âm chính) ngắn, nguyên âm chính dài nhất
    k = len(pts)
    if k == 1:
        knots, vals = [0, 1], [pts[0], pts[0]]
    else:
        main = 0 if k == 2 and nucleus[0] not in "uoi" else min(1, k - 1)
        knots = np.linspace(0, 1, k + 1)[:-1]
        knots[main:] = np.linspace(0.15 if main else 0, 0.72, k - main)
        knots = list(knots) + [1.0]
        vals = pts + [pts[-1]]
    if coda in ("m", "n", "ng", "nh"):
        knots = [x * 0.7 for x in knots[:-1]] + [0.8, 1.0]
        vals = vals[:-1] + [NASAL, NASAL]
    u = np.linspace(0, 1, n)
    return [np.interp(u, knots, [v[j] for v in vals]) * scale for j in range(3)]


def _consonant(onset, sp, rng, next_f):
    """Phụ âm đầu: trả về (đoạn âm, có rung thanh không)."""
    F = sp["F"]

    def burst(dur, band, gain=1.0):
        n = int(dur * SR)
        x = sosfilt(_sos("band", band), rng.standard_normal(n))
        return x * np.exp(-np.arange(n) / SR * (3 / dur)) * gain

    def hiss(dur, band, gain=0.5):
        n = int(dur * SR)
        x = sosfilt(_sos("band", band), rng.standard_normal(n))
        return x * np.sin(np.pi * np.linspace(0, 1, n)) ** 0.6 * gain

    def murmur(dur, f=(260, 1100), gain=0.35):
        n = int(dur * SR)
        src = glottal_source(np.full(n, sp["f0"] * 0.97), rng, 0.01, 0.05, 0.0)
        y = formant_filter(src, [(np.full(n, f[0] * F), 90, 1.0), (np.full(n, f[1] * F), 200, 0.2)])
        return y / (np.abs(y).max() + 1e-9) * gain * np.minimum(np.linspace(0, 4, n), 1)

    if onset in ("s", "x"):
        return hiss(0.11, (3800 * F, 9000) if onset == "s" else (3000 * F, 8000), 0.45)
    if onset in ("ch", "tr"):
        return np.concatenate([np.zeros(int(0.03 * SR)), hiss(0.06, (2400 * F, 7000), 0.55)])
    if onset == "ph":
        return hiss(0.08, (1200, 7000), 0.25)
    if onset in ("th", "kh"):
        return np.concatenate([np.zeros(int(0.03 * SR)), burst(0.05, (1500, 6000), 0.5)])
    if onset == "h":
        n = int(0.06 * SR)
        x = rng.standard_normal(n) * np.sin(np.pi * np.linspace(0, 1, n))
        return formant_filter(x, [(np.full(n, next_f[j]), 200, 1.0) for j in range(3)]) * 0.08
    if onset in ("t", "c", "k", "qu", "p"):
        band = {"t": (3000, 8000), "p": (500, 2500)}.get(onset, (1400, 3600))
        return np.concatenate([np.zeros(int(0.035 * SR)), burst(0.018, band, 0.7)])
    if onset in ("b", "đ"):
        return np.concatenate([murmur(0.03, (250, 700), 0.2), burst(0.01, (300, 3000) if onset == "đ" else (200, 1500), 0.4)])
    if onset in ("m", "n", "nh", "ng", "ngh"):
        f2 = {"m": 900, "n": 1400, "nh": 2000}.get(onset, 1200)
        return murmur(0.07, (250, f2), 0.4)
    if onset in ("d", "gi", "v", "r", "l", "g", "gh"):
        f = {"l": (360, 1150), "v": (300, 900), "r": (400, 1300), "g": (300, 1200), "gh": (300, 1200)}.get(onset, (300, 2100))
        return murmur(0.05, f, 0.3)
    return np.zeros(0)


def syllable(word, sp, rng, dur=0.21, f0_mult=1.0, lift=0.0):
    onset, nucleus, coda, tone = parse(word)
    if coda in ("t", "c", "p", "ch"):
        dur *= 0.72
    if tone == "nang":
        dur *= 0.75
    elif tone in ("huyen", "nga", "hoi"):
        dur *= 1.12
    n = int(dur / sp["rate"] * SR)
    u = np.linspace(0, 1, n)
    st = np.interp(u, [0, 0.5, 1], TONES[tone]) + lift
    f0 = sp["f0"] * f0_mult * 2 ** (st / 12)
    f0 *= 1 + 0.006 * np.sin(2 * np.pi * 5.5 * u * dur)
    src = glottal_source(f0, rng, jitter=0.008 + 0.03 * sp["rough"], shimmer=0.05 + 0.3 * sp["rough"],
                         sub=0.5 * sp["rough"], open_q=0.62)
    src = src / (np.abs(src).max() + 1e-9)
    asp = rng.standard_normal(n) * (0.04 + 0.1 * sp["rough"])
    path = _formant_path(nucleus, coda, n, sp["F"])
    tracks = [(path[0], 90, 1.0), (path[1], 120, 0.75), (path[2], 180, 0.45),
              (np.full(n, 3600 * sp["F"]), 300, 0.2)]
    y = formant_filter(src + asp, tracks)
    y = y + 0.8 * np.diff(y, prepend=0) * SR / 3000  # nâng dải cao cho rõ phụ âm, đỡ ù
    y = y / (np.abs(y).max() + 1e-9)
    env = np.minimum(u * dur / 0.018, 1) * np.minimum((1 - u) * dur / 0.04, 1)
    if coda in ("t", "c", "p", "ch"):
        env *= np.where(u > 0.88, 0, 1)   # tắt gọn
    if tone == "nang":
        env *= np.where(u > 0.8, 0.15, 1)
    if tone == "nga":
        env *= 1 - 0.6 * np.exp(-((u - 0.5) / 0.08) ** 2)  # gãy giữa tiếng
    if coda in ("m", "n", "ng", "nh"):
        env *= np.where(u > 0.75, 0.55, 1)
    y *= env
    head = _consonant(onset, sp, rng, [p[0] for p in path])
    return np.concatenate([head, y])


def say(text, speaker="coba", mood="", f0_mult=1.0, gap=0.025):
    """Cả câu: dấu phẩy nghỉ ngắn, cuối câu kéo dài; mood 'vui' cao và nảy hơn, 'gat' to, nhanh, khàn."""
    sp = dict(SPEAKERS[speaker])
    rng = np.random.default_rng(zlib.crc32((text + speaker).encode()))  # cùng câu thì ra y hệt
    if mood == "vui":
        sp["rate"] *= 1.08
        f0_mult *= 1.08
    elif mood == "gat":
        sp["rate"] *= 1.18
        sp["rough"] += 0.15
        f0_mult *= 1.2
    elif mood == "tho":  # nói khẽ, thì thầm
        sp["rough"] += 0.4
    words = text.replace(",", " , ").replace("!", " ! ").replace("?", " ? ").replace(".", " . ").split()
    syl = [w for w in words if w not in ",!?."]
    out = []
    k = 0
    for w in words:
        if w in ",.":
            out.append(np.zeros(int(0.12 * SR)))
            continue
        if w in "!?":
            continue
        last = k == len(syl) - 1
        decl = 1.0 - 0.06 * k / max(len(syl) - 1, 1)   # câu nói hạ giọng dần
        lift = 0.0
        if mood == "vui" and k % 2 == 0:
            lift = 1.0
        if last and text.rstrip().endswith("!"):
            lift += 1.5
        if last and text.rstrip().endswith("?"):
            lift += 3.0
        out.append(syllable(w, sp, rng, 0.3 if last else 0.2, f0_mult * decl, lift))
        out.append(np.zeros(int(gap * SR)))
        k += 1
    y = np.concatenate(out)
    y = sosfilt(_sos("high", 90), y)
    return y / (np.abs(y).max() + 1e-9)

