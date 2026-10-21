import numpy as np
def v(*a): return np.array(a, np.float32)

# ---------- hàm SDF cơ bản ----------
def ellipsoid(p, c, r):
    q = (p - c) / r
    k0 = np.linalg.norm(q, axis=-1)
    k1 = np.linalg.norm(q / r, axis=-1)
    return k0 * (k0 - 1) / np.maximum(k1, 1e-6)

def sphere(p, c, r): return np.linalg.norm(p - c, axis=-1) - r

def roundcone(p, a, b, r1, r2):
    """Đoạn a→b, bán kính r1 ở a, r2 ở b (côn bo tròn)."""
    ba = b - a; l2 = ba @ ba; rr = r1 - r2; a2 = l2 - rr * rr; il2 = 1.0 / l2
    pa = p - a; y = pa @ ba; z = y - l2
    xv = pa * l2 - y[..., None] * ba
    x2 = (xv * xv).sum(-1); y2 = y * y * l2; z2 = z * z * l2
    k = np.sign(rr) * rr * rr * x2
    d = np.where(np.sign(z) * a2 * z2 > k, np.sqrt(x2 + z2) * il2 - r2,
        np.where(np.sign(y) * a2 * y2 < k, np.sqrt(x2 + y2) * il2 - r1,
                 (np.sqrt(x2 * a2 * il2) + y * rr) * il2 - r1))
    return d

def smin(a, b, k):
    h = np.clip(0.5 + 0.5 * (b - a) / k, 0, 1)
    return b * (1 - h) + a * h - k * h * (1 - h)

def smax(a, b, k): return -smin(-a, -b, k)

def chain(p, pts, rads, k=0.01):
    d = None
    for i in range(len(pts) - 1):
        di = roundcone(p, pts[i], pts[i + 1], rads[i], rads[i + 1])
        d = di if d is None else smin(d, di, k)
    return d

def catmull(pts, n):
    pts = np.array(pts, np.float32); P_ = np.vstack([pts[0], pts, pts[-1]]); out = []
    for i in range(1, len(P_) - 2):
        p0, p1, p2, p3 = P_[i - 1], P_[i], P_[i + 1], P_[i + 2]
        for t in np.linspace(0, 1, n, endpoint=False):
            out.append(0.5 * (2 * p1 + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t * t + (-p0 + 3 * p1 - 3 * p2 + p3) * t ** 3))
    out.append(pts[-1]); return np.array(out, np.float32)

def hexc(h): h = h.lstrip('#'); return np.array([int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)], np.float32)

FUR, FUR2, BELLY, EARIN, NOSE, LINE = map(hexc, ['#E8913A', '#C2621A', '#FBE3C2', '#EE9488', '#C8412F', '#3A2418'])

def sstep(a, b, x): t = np.clip((x - a) / (b - a), 0, 1); return t * t * (3 - 2 * t)

def noise(p):
    x, y, z = p[:, 0], p[:, 1], p[:, 2]
    return (np.sin(x * 41 + y * 13) + np.sin(y * 37 - z * 23 + 1.3) + np.sin(z * 29 + x * 17 + 2.1)) / 3

