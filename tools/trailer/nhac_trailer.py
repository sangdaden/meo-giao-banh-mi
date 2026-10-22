"""Nhạc nền trailer (~75 giây, 100 BPM), tự tổng hợp bằng bộ nhạc cụ của tools/sound/synth.py (CC0).

Chạy:  python3 tools/trailer/nhac_trailer.py <ra.wav>
In ra mốc giây của từng đoạn để dựng hình khớp nhịp (1 ô nhịp = 2,4 giây).
Đoạn "Mực" để trống cho tiếng ngáy và tiếng sủa trộn lúc dựng.
"""
import os
import sys
import wave

import numpy as np

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "sound"))
import synth  # noqa: E402
from synth import SR, kick, mix_at, note, pad, song, staccato, tranh, mari  # noqa: E402

synth.loopify = lambda x, length: x  # đoạn nối thẳng, giữ đuôi vang thay vì cuộn về đầu

BPM = 100
BAR = 60 / BPM * 4
CHORDS = ["D2 F#3 A3 D4", "B1 F#3 B3 D4", "G2 G3 B3 D4", "A2 E3 A3 C#4"]
THEME = "F#5 ~ A5 F#5 E5 ~ D5 ~  E5 ~ A4 ~ B4 D5 E5 ~  F#5 ~ A5 ~ B5 A5 F#5 ~  E5 D5 B4 ~ D5 ~ E5 ~ "

# tên, số ô nhịp, hợp âm, giai điệu, nhạc cụ, các bè
SECTIONS = [
    ("mo", 2, CHORDS, "A4 ~ ~ ~ D5 ~ E5 ~  F#5 ~ ~ ~ ~ ~ - -", tranh,
     {"melody": 0.5, "pad": 0.14, "reverb": 0.5}),
    ("bep", 4, CHORDS, "D5 - F#5 - A5 - F#5 E5  D5 ~ B4 ~ A4 ~ - -  B4 - D5 - E5 - D5 B4  A4 ~ ~ ~ - - - -", mari,
     {"melody": 0.6, "bass": 0.3, "bass_pattern": [(0, 1, 1), (1.5, 1, 0.5), (2, 2, 1), (3, 1, 1)],
      "arp": 0.1, "kick": 0.28, "hat": 0.08, "swing": True, "shaker": 0.05, "reverb": 0.3}),
    ("pho", 5, CHORDS, THEME + " F#5 ~ ~ ~ A5 ~ ~ ~", tranh,
     {"melody": 0.5, "bass": 0.32, "stab": 0.15, "kick": 0.4, "snare": 0.26, "hat": 0.12, "shaker": 0.06, "reverb": 0.22}),
    ("muc", 2.5, None, None, None, {}),
    ("tuan", 9, CHORDS, THEME + " F#5 ~ A5 F#5 E5 ~ D5 ~  E5 ~ F#5 A5 B5 ~ A5 ~  B5 ~ A5 F#5 E5 ~ D5 E5  F#5 ~ E5 ~ D5 ~ B4 ~  D5 ~ ~ ~ ~ ~ - -", tranh,
     {"melody": 0.5, "bass": 0.34, "stab": 0.16, "kick": 0.42, "snare": 0.28, "hat": 0.13, "shaker": 0.06, "pad": 0.06, "reverb": 0.22}),
    ("tu_do", 3, CHORDS, "D5 F#5 A5 F#5 B5 A5 F#5 E5  D5 E5 F#5 A5 B5 ~ A5 ~  F#5 E5 D5 B4 A4 ~ D5 ~", staccato,
     {"melody": 0.45, "bass": 0.4, "bass_pattern": [(k * 0.5, 2 if k % 4 == 3 else 1, 0.45) for k in range(8)],
      "kick": 0.45, "kick_beats": [0, 1, 2, 3], "hat": 0.13, "reverb": 0.18}),
    ("ket", 5, CHORDS[:4] + ["D2 F#3 A3 D4"], "A4 ~ B4 ~ D5 ~ E5 ~  F#5 ~ ~ ~ E5 ~ D5 ~  B4 ~ D5 ~ E5 ~ /A5 ~  F#5 ~ ~ ~ ~ ~ ~ ~  D5 ~ ~ ~ ~ ~ ~ ~", tranh,
     {"melody": 0.55, "pad": 0.14, "bass": 0.28, "bass_pattern": [(0, 1, 2), (2, 1, 2)], "shaker": 0.04, "reverb": 0.5}),
]


def build():
    total = sum(s[1] for s in SECTIONS) * BAR + 5
    out = np.zeros((int(total * SR), 2))
    t = 0.0
    marks = []
    for name, bars, chords, mel, inst, parts in SECTIONS:
        marks.append((name, t))
        if mel:
            x = song(BPM, int(np.ceil(bars)), chords, mel, inst, parts)
            if name == "ket":  # hợp âm Rê ngân dài ở ô nhịp cuối
                ring = pad([note(n) for n in ("F#3", "A3", "D4", "D5")], 6.0) * 0.18
                k = int((bars - 1) * BAR * SR)
                x[k:k + len(ring), 0] += ring[: len(x) - k]
                x[k:k + len(ring), 1] += ring[: len(x) - k]
            n = int(t * SR)
            m = min(len(x), len(out) - n)
            out[n:n + m] += x[:m]
        else:  # đoạn Mực: im, chỉ một nhịp trống dội ở cuối (cú "GÂU")
            hit = kick(0.8) * 0.9
            k = int((t + bars * BAR - 60 / BPM / 2) * SR)
            out[k:k + len(hit), 0] += hit
            out[k:k + len(hit), 1] += hit
        t += bars * BAR
    marks.append(("het", t))
    out /= np.max(np.abs(out)) / 0.85
    end = int((t + 3.5) * SR)
    out = out[:end]
    out[-int(2.5 * SR):] *= np.linspace(1, 0, int(2.5 * SR))[:, None]
    return out, marks


def main():
    dst = sys.argv[1] if len(sys.argv) > 1 else "nhac_trailer.wav"
    x, marks = build()
    pcm = (np.clip(x, -1, 1) * 32767).astype(np.int16)
    with wave.open(dst, "wb") as w:
        w.setnchannels(2)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())
    for name, s in marks:
        print("%-6s %6.2f" % (name, s))
    print("dài %.1f giây" % (len(x) / SR))


if __name__ == "__main__":
    main()
