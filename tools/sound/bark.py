"""Tiếng chó sủa tổng hợp theo mô hình nguồn-bộ lọc, giống cách tạo giọng nói:

1. Nguồn: chuỗi xung thanh môn (dạng Rosenberg) có rung cao độ (jitter), rung biên độ
   (shimmer) và nhịp đôi (subharmonic) để ra chất khàn, thô của tiếng sủa thật;
   cộng thêm hơi thở (nhiễu) cùng nhịp.
2. Bộ lọc: 4 formant đổi theo thời gian, mô phỏng miệng chó há ra rồi khép lại:
   "g-ẩ-u" (formant thấp, mở rộng lên, rồi khép).
3. Bao biên: vào rất gắt (~8 ms), đỉnh ở 30-40 ms, tắt dần trong ~150 ms, có hơi "f" cuối.

Dùng từ synth.py: bark_v2(kind) trả về mảng mono 44,1 kHz.
"""
import numpy as np
from scipy.signal import lfilter

SR = 44100


def _resonator_coeffs(f, bw):
    r = np.exp(-np.pi * bw / SR)
    th = 2 * np.pi * f / SR
    a = [1, -2 * r * np.cos(th), r * r]
    b = [1 - r]  # chuẩn hóa thô để các formant ngang nhau
    return b, a


def formant_filter(x, tracks, block=64):
    """tracks: list (f_curve, bw, gain) với f_curve là mảng tần số theo mẫu. Lọc song song."""
    out = np.zeros(len(x))
    for f_curve, bw, gain in tracks:
        zi = np.zeros(2)
        y = np.zeros(len(x))
        for i in range(0, len(x), block):
            b, a = _resonator_coeffs(float(f_curve[min(i, len(x) - 1)]), bw)
            y[i:i + block], zi = lfilter(b, a, x[i:i + block], zi=zi)
        out += y * gain
    return out


def glottal_source(f0, rng, jitter=0.03, shimmer=0.25, sub=0.35, open_q=0.6):
    """Chuỗi xung Rosenberg với rung cao độ, rung biên độ và nhịp đôi (tiếng khàn)."""
    n = len(f0)
    out = np.zeros(n)
    t = 0.0
    k = 0
    while True:
        i = int(t)
        if i >= n:
            break
        period = SR / (f0[i] * (1 + jitter * rng.standard_normal()))
        amp = 1 + shimmer * rng.standard_normal()
        if k % 2 == 1:
            amp *= 1 - sub  # nhịp đôi: xung lẻ yếu hơn
        L = int(period)
        tp = int(L * open_q * 0.66)
        tn = int(L * open_q * 0.34)
        pulse = np.zeros(L)
        if tp > 1:
            pulse[:tp] = 0.5 * (1 - np.cos(np.pi * np.arange(tp) / tp))
        if tn > 1:
            pulse[tp:tp + tn] = np.cos(np.pi / 2 * np.arange(tn) / tn)
        d = np.diff(pulse, prepend=0)  # đạo hàm luồng khí, giống bức xạ từ miệng
        m = min(L, n - i)
        out[i:i + m] += d[:m] * amp
        t += period
        k += 1
    return out


def bark_v2(kind="vua", seed=1):
    rng = np.random.default_rng(seed)
    # Chó Mực to cỡ chó ta trưởng thành: giọng trung, hơi trầm
    p = {
        "vua": dict(dur=0.24, f0=(300, 420, 230), F=(1.0, 1.0), rough=0.35, breath=0.25),
        "tram": dict(dur=0.28, f0=(220, 310, 170), F=(0.85, 0.88), rough=0.45, breath=0.3),
        "kho": dict(dur=0.22, f0=(340, 470, 260), F=(1.05, 1.0), rough=0.6, breath=0.45),
    }[kind]
    n = int(p["dur"] * SR)
    u = np.arange(n) / n
    a, peak, end = p["f0"]
    # Cao độ hình chữ U ngược: vọt lên nhanh rồi rơi
    f0 = np.where(u < 0.25, a + (peak - a) * (u / 0.25) ** 0.6, peak + (end - peak) * np.clip((u - 0.25) / 0.75, 0, 1) ** 1.3)
    src = glottal_source(f0, rng, jitter=0.02 + 0.03 * p["rough"], shimmer=0.15 + 0.3 * p["rough"], sub=p["rough"])
    # Hơi thở theo nhịp xung, cộng nhiễu cuối tiếng ("f")
    noise = rng.standard_normal(n)
    breath = noise * p["breath"] * 0.15 * (0.4 + np.abs(src) / (np.abs(src).max() + 1e-9))
    tail = noise * 0.2 * np.clip((u - 0.6) / 0.4, 0, 1) * p["breath"]
    exc = src + breath + tail
    # Formant: miệng há ra (F1 lên) rồi khép (F1 xuống), F2 đi theo
    open_ = np.sin(np.pi * np.clip(u / 0.8, 0, 1)) ** 0.7
    s1, s2 = p["F"]
    tracks = [
        ((380 + 420 * open_) * s1, 160, 1.0),
        ((1050 + 350 * open_) * s2, 200, 1.3),
        (np.full(n, 2400 * s2), 280, 1.1),
        (np.full(n, 3500 * s2), 400, 0.6),
    ]
    y = formant_filter(exc, tracks)
    y = y + 1.5 * np.diff(y, prepend=0) * SR / 6000  # nâng dải cao: tiếng sủa thật gắt, sáng
    # Bao biên: gắt vào, đỉnh 35 ms, tắt dần
    t = np.arange(n) / SR
    env = np.minimum(t / 0.008, 1) * np.exp(-np.maximum(t - 0.035, 0) * 14)
    y *= env
    # Ngực dội trầm làm tiếng chắc hơn
    y += 0.06 * np.max(np.abs(y)) * np.sin(2 * np.pi * np.cumsum(f0 / 2) / SR) * env * np.exp(-t * 25)
    y[-int(0.01 * SR):] *= np.linspace(1, 0, int(0.01 * SR))
    return y / (np.abs(y).max() + 1e-9)
