"""AT3: đo độ to (LUFS, chuẩn ITU-R BS.1770-4 / EBU R128) của nhạc và tiếng nền, và kiểm trong CI.

Mức chuẩn của game (giữ cho đổi bài, đổi ngày không bị to nhỏ thất thường):
  music_*.ogg, jingle_*.ogg   -18 LUFS
  amb_*.ogg                   -24 LUFS
Lệch quá DUNG_SAI (LU) thì báo đỏ. tools/sound/synth.py dùng chính hàm lufs() ở đây để chỉnh mức khi ghi file,
nên file làm lại bằng synth.py luôn đạt; file lấy từ nơi khác thì chỉnh gain cho tới khi script này xanh.

Chạy:  pip install numpy scipy soundfile
       python3 tools/sound/do_lufs.py              # kiểm mọi file nhạc/tiếng nền trong assets/audio/
       python3 tools/sound/do_lufs.py file.ogg     # chỉ đo, in số
In "LUFS OK" khi mọi file đạt (CI grep chữ này).
"""
import glob
import os
import sys

import numpy as np
from scipy.signal import lfilter

MUC = {"music_": -18.0, "jingle_": -18.0, "amb_": -24.0}
DUNG_SAI = 1.0
## Bài nhạc nền (music_*) phải dài 90–120 s và có đoạn A/B (AT1); jingle là câu ngắn nên không tính.
NHAC_DAI = (90.0, 120.0)
THU_MUC = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "assets", "audio")


def _k_weight(sr):
    """Hai tầng lọc K của BS.1770 (kệ cao ~1,5 kHz +4 dB rồi cắt thấp ~38 Hz), tính lại cho mọi tần số mẫu."""
    # tầng 1: high shelf
    G, Q, fc = 3.99984385397, 0.7071752369554193, 1681.974450955533
    K = np.tan(np.pi * fc / sr)
    Vh, Vb = 10 ** (G / 20), (10 ** (G / 20)) ** 0.4996667741545416
    a0 = 1 + K / Q + K * K
    b1 = [(Vh + Vb * K / Q + K * K) / a0, 2 * (K * K - Vh) / a0, (Vh - Vb * K / Q + K * K) / a0]
    a1 = [1, 2 * (K * K - 1) / a0, (1 - K / Q + K * K) / a0]
    # tầng 2: high pass
    Q, fc = 0.5003270373238773, 38.13547087602444
    K = np.tan(np.pi * fc / sr)
    a0 = 1 + K / Q + K * K
    b2 = [1, -2, 1]
    a2 = [1, 2 * (K * K - 1) / a0, (1 - K / Q + K * K) / a0]
    return (b1, a1), (b2, a2)


def lufs(x, sr=44100):
    """Độ to tích hợp (LUFS) của mảng mẫu: 1 kênh (n,) hoặc nhiều kênh (n, kênh). Trả -70 nếu gần như im lặng."""
    x = np.asarray(x, dtype=np.float64)
    if x.ndim == 1:
        x = x[:, None]
    (b1, a1), (b2, a2) = _k_weight(sr)
    y = lfilter(b2, a2, lfilter(b1, a1, x, axis=0), axis=0)
    blk, hop = int(0.4 * sr), int(0.1 * sr)
    if len(y) < blk:
        y = np.pad(y, ((0, blk - len(y)), (0, 0)))
    n = 1 + (len(y) - blk) // hop
    sq = np.cumsum(np.vstack([np.zeros((1, y.shape[1])), y * y]), axis=0)
    starts = np.arange(n) * hop
    z = (sq[starts + blk] - sq[starts]) / blk          # công suất mỗi khối 400 ms, mỗi kênh
    p = z.sum(axis=1)                                  # trái + phải, hệ số kênh 1,0
    with np.errstate(divide="ignore"):
        l_blk = -0.691 + 10 * np.log10(p)
    keep = l_blk > -70.0                               # cổng tuyệt đối
    if not keep.any():
        return -70.0
    rel = -0.691 + 10 * np.log10(p[keep].mean()) - 10.0  # cổng tương đối
    keep &= l_blk > rel
    return float(-0.691 + 10 * np.log10(p[keep].mean()))


def muc_cua(name):
    """Mức chuẩn (LUFS) cho file tên `name` (không đuôi), None nếu không phải nhạc/tiếng nền."""
    return next((v for k, v in MUC.items() if name.startswith(k)), None)


def _doc(path):
    import soundfile as sf
    x, sr = sf.read(path, always_2d=True)
    return x, sr


def kiem(files):
    loi = []
    for f in sorted(files):
        name = os.path.splitext(os.path.basename(f))[0]
        muc = muc_cua(name)
        if muc is None:
            continue
        x, sr = _doc(f)
        l = lufs(x, sr)
        dai = len(x) / sr
        dat = abs(l - muc) <= DUNG_SAI
        ghi = ""
        if name.startswith("music_") and not NHAC_DAI[0] - 0.5 <= dai <= NHAC_DAI[1] + 0.5:
            dat = False
            ghi = "  (bài nhạc phải dài %d–%d s)" % NHAC_DAI
        print("%-24s %6.1f LUFS  (chuẩn %5.1f)  %6.1f s  %s%s" % (name, l, muc, dai, "ok" if dat else "LỆCH", ghi))
        if not dat:
            loi.append(name)
    if loi:
        print("LUFS LỖI: %s. Làm lại bằng tools/sound/synth.py (tự chỉnh mức) hoặc chỉnh gain file." % ", ".join(loi))
        return 1
    print("LUFS OK")
    return 0


if __name__ == "__main__":
    args = sys.argv[1:]
    if args:
        for a in args:
            x, sr = _doc(a)
            print("%s  %.2f LUFS  đỉnh %.2f dBFS" % (a, lufs(x, sr), 20 * np.log10(np.abs(x).max() + 1e-12)))
    else:
        sys.exit(kiem(glob.glob(os.path.join(THU_MUC, "*.ogg")) + glob.glob(os.path.join(THU_MUC, "*.wav"))))
