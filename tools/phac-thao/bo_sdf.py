"""Bơ dựng bằng SDF (hàm khoảng cách có dấu) + hòa khối mềm (smooth union),
rồi marching cubes ra lưới. Toạ độ theo three.js: mét, Y lên, mèo nhìn +Z.
Xuất: bo_body.npz, bo_scarf.npz (verts, faces, colors)."""
import numpy as np, sys
from skimage import measure

H = float(sys.argv[1]) if len(sys.argv) > 1 else 0.003
OUT = sys.argv[2] if len(sys.argv) > 2 else '.'

# ---------- lưới điểm ----------
xs = np.arange(-0.21, 0.21, H, dtype=np.float32)
ys = np.arange(-0.01, 0.70, H, dtype=np.float32)
zs = np.arange(-0.46, 0.44, H, dtype=np.float32)
X, Y, Z = np.meshgrid(xs, ys, zs, indexing='ij')
P = np.stack([X, Y, Z], -1)

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

# ---------- tham số Bơ (giữ tỉ lệ bo-model.js) ----------
bY = 0.27
HEAD_C = v(0, 0.42, 0.195); HEAD_R = v(0.148, 0.132, 0.136)

def ear_sdf(p, side):
    base = v(side * 0.078, 0.495, 0.19)
    up = v(side * 0.36, 0.93, -0.05); up /= np.linalg.norm(up)
    fwd = v(0, 0.05, 1.0); fwd -= up * (fwd @ up); fwd /= np.linalg.norm(fwd)
    rt = np.cross(up, fwd)
    q = p - base
    lx, ly, lz = q @ rt, q @ up, q @ fwd
    loc = np.stack([lx, ly, lz * 2.6], -1)               # ép dẹt theo chiều dày tai
    outer = roundcone(loc, v(0, -0.02, 0), v(0, 0.105, 0), 0.058, 0.007) / 2.6 * 1.6
    inner = roundcone(np.stack([lx * 1.15, ly - 0.012, (lz - 0.02) * 2.6], -1),
                      v(0, -0.0, 0), v(0, 0.095, 0), 0.046, 0.004) / 2.6 * 1.6
    return smax(outer, -inner, 0.006), (lx, ly, lz)

def body_sdf(p):
    # thân: ngực + hông hòa nhau, lưng hơi võng
    d = ellipsoid(p, v(0, 0.29, 0.085), v(0.128, 0.128, 0.155))
    d = smin(d, ellipsoid(p, v(0, 0.28, -0.095), v(0.132, 0.122, 0.15)), 0.05)
    # bụng tròn phía dưới
    d = smin(d, ellipsoid(p, v(0, 0.235, 0.0), v(0.11, 0.08, 0.17)), 0.04)
    # cổ ngắn / ngực trước nối lên đầu
    d = smin(d, ellipsoid(p, v(0, 0.345, 0.16), v(0.105, 0.1, 0.085)), 0.05)
    # đùi sau (khối mông)
    for s in (-1, 1):
        d = smin(d, ellipsoid(p, v(s * 0.072, 0.255, -0.125), v(0.06, 0.1, 0.095)), 0.035)
    # chân sau: đùi → gối → cổ chân (khuỷu gót) → bàn
    for s in (-1, 1):
        x = s * 0.08
        leg = chain(p, [v(x, 0.25, -0.12), v(x, 0.15, -0.07), v(x, 0.085, -0.165), v(x, 0.03, -0.145)],
                    [0.052, 0.036, 0.026, 0.025], 0.012)
        paw = ellipsoid(p, v(x, 0.022, -0.125), v(0.034, 0.023, 0.047))
        for t in (-1, 0, 1):
            paw = smin(paw, sphere(p, v(x + t * 0.017, 0.016, -0.09 + (0.004 if t == 0 else 0)), 0.014), 0.008)
        d = smin(d, smin(leg, paw, 0.015), 0.03)
    # chân trước: vai → khuỷu → cổ tay → bàn
    for s in (-1, 1):
        x = s * 0.077
        leg = chain(p, [v(x * 0.9, 0.31, 0.12), v(x, 0.17, 0.115), v(x, 0.05, 0.13)], [0.048, 0.033, 0.027], 0.012)
        paw = ellipsoid(p, v(x, 0.022, 0.145), v(0.034, 0.023, 0.046))
        for t in (-1, 0, 1):
            paw = smin(paw, sphere(p, v(x + t * 0.017, 0.016, 0.18 - (0.0 if t == 0 else 0.004)), 0.014), 0.008)
        d = smin(d, smin(leg, paw, 0.015), 0.03)
    # đuôi: cong chữ J dựng lên như bản cũ
    tp = catmull([[0, 0.29, -0.2], [0, 0.265, -0.3], [0, 0.39, -0.37], [0, 0.53, -0.34], [0, 0.6, -0.26]], 6)
    rads = np.linspace(0.034, 0.026, len(tp)).astype(np.float32)
    d = smin(d, chain(p, list(tp), list(rads), 0.006), 0.03)
    # đầu
    hd = ellipsoid(p, HEAD_C, HEAD_R)
    for s in (-1, 1):  # má phúng
        hd = smin(hd, ellipsoid(p, v(s * 0.065, 0.38, 0.255), v(0.075, 0.062, 0.06)), 0.03)
    for s in (-1, 1):  # đệm ria
        hd = smin(hd, ellipsoid(p, v(s * 0.022, 0.378, 0.315), v(0.032, 0.026, 0.026)), 0.012)
    hd = smin(hd, ellipsoid(p, v(0, 0.355, 0.3), v(0.03, 0.02, 0.025)), 0.012)          # cằm
    hd = smin(hd, ellipsoid(p, v(0, 0.415, 0.305), v(0.034, 0.03, 0.03)), 0.02)          # sống mũi
    hd = smin(hd, ellipsoid(p, v(0, 0.401, 0.334), v(0.015, 0.009, 0.009)), 0.006)        # mũi
    for s in (-1, 1):  # hốc mắt
        hd = smax(hd, -sphere(p, v(s * 0.056, 0.437, 0.31), 0.034), 0.012)
    for s in (-1, 1):
        e, _ = ear_sdf(p, s); hd = smin(hd, e, 0.012)
    d = smin(d, hd, 0.035)
    return d

def scarf_sdf(p, body):
    # khăn = vỏ bám theo thân, cắt bởi một dải nghiêng quanh chỗ đầu gặp thân
    n = v(0, 0.75, 0.66); n /= np.linalg.norm(n)
    c = v(0, 0.345, 0.15)
    plane = (p - c) @ n
    ang = np.arctan2(p[..., 0], p[..., 2] - 0.15)
    wav = 0.003 * np.sin(ang * 9) + 0.002 * np.sin(ang * 17 + 1.0)
    band = np.abs(plane + wav) - 0.03
    shell = np.abs(body - 0.016) - 0.017
    d = smax(shell, band, 0.008)
    d = smax(d, -(body), 0.004)
    d = smax(d, sphere(p, v(0, 0.35, 0.15), 0.17), 0.01)
    # nút thắt ở sau-trái, hai đuôi khăn rủ xuống vai
    # tìm điểm trên mặt thân ở phía sau-trái cổ rồi đặt nút thắt ra ngoài
    c0 = v(0, 0.35, 0.15); dr = v(-0.8, 0.15, -0.55); dr /= np.linalg.norm(dr)
    t_ = 0.0
    while body_sdf(np.array([c0 + dr * t_]))[0] < 0: t_ += 0.003
    k = c0 + dr * (t_ + 0.022)
    d = smin(d, ellipsoid(p, k, v(0.03, 0.026, 0.024)), 0.01)
    t1 = chain(p, [k, k + v(-0.02, -0.05, -0.0), k + v(-0.03, -0.1, 0.01)], [0.016, 0.014, 0.018], 0.004)
    t2 = chain(p, [k, k + v(-0.012, -0.04, -0.045), k + v(-0.02, -0.085, -0.07)], [0.015, 0.013, 0.017], 0.004)
    # ép dẹt hai đuôi khăn
    d = smin(d, t1, 0.008); d = smin(d, t2, 0.008)
    return d

def hexc(h): h = h.lstrip('#'); return np.array([int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)], np.float32)

FUR, FUR2, BELLY, EARIN, NOSE, LINE = map(hexc, ['#E8913A', '#C2621A', '#FBE3C2', '#EE9488', '#C8412F', '#3A2418'])

def sstep(a, b, x): t = np.clip((x - a) / (b - a), 0, 1); return t * t * (3 - 2 * t)

def noise(p):
    x, y, z = p[:, 0], p[:, 1], p[:, 2]
    return (np.sin(x * 41 + y * 13) + np.sin(y * 37 - z * 23 + 1.3) + np.sin(z * 29 + x * 17 + 2.1)) / 3

def body_colors(V, N):
    x, y, z = V[:, 0], V[:, 1], V[:, 2]
    col = np.tile(FUR, (len(V), 1))
    nz = noise(V)
    # vằn thân/chân: các dải ngang quanh mình, chỉ ở phía trên/hông
    on_body = sstep(0.1, 0.16, y) * sstep(0.2, 0.14, z) * sstep(-0.26, -0.21, z)
    s = np.sin(z * 105 + nz * 1.6 + np.abs(x) * 10)
    stripe = sstep(0.35, 0.65, s) * sstep(-0.1, 0.35, N[:, 1] + 0.35) * on_body * sstep(0.8, 0.55, np.abs(N[:, 2]))
    # vằn chân: vòng ngang
    on_leg = sstep(0.22, 0.16, y) * sstep(0.045, 0.06, y)
    stripe = np.maximum(stripe, sstep(0.45, 0.75, np.sin(y * 120 + nz)) * on_leg * sstep(0.2, 0.6, np.abs(N[:, 0])))
    # vằn đuôi: vòng theo chiều cao/chiều dọc đuôi
    on_tail = sstep(-0.22, -0.26, z)
    stripe = np.maximum(stripe, sstep(0.3, 0.6, np.sin((y * 1.0 - z * 0.6) * 85 + nz)) * on_tail)
    # trán: chữ M (3 vạch dọc) + vạch má
    fore = sstep(0.44, 0.47, y) * sstep(0.18, 0.22, z) * sstep(0.065, 0.05, np.abs(x))
    stripe = np.maximum(stripe, sstep(0.55, 0.85, np.cos(x * 150)) * fore)
    head_top = sstep(0.46, 0.49, y) * sstep(0.06, 0.1, z) * sstep(0.22, 0.18, z) * sstep(0.09, 0.07, np.abs(x))
    stripe = np.maximum(stripe, sstep(0.5, 0.8, np.cos(x * 75)) * head_top)
    cheek = sstep(0.09, 0.11, np.abs(x)) * sstep(0.36, 0.38, y) * sstep(0.45, 0.43, y) * sstep(0.16, 0.19, z) * sstep(0.28, 0.25, z)
    stripe = np.maximum(stripe, sstep(0.55, 0.85, np.sin(y * 210 + 1.5)) * cheek)
    col = col * (1 - stripe[:, None]) + FUR2 * stripe[:, None]
    # bụng/ngực/mõm/bàn chân: kem
    belly = sstep(0.2, -0.45, N[:, 1]) * sstep(0.32, 0.27, y) * sstep(0.1, 0.14, y) * sstep(-0.22, -0.17, z)
    chest = sstep(0.2, 0.27, z) * sstep(0.37, 0.33, y) * sstep(0.085, 0.05, np.abs(x)) * sstep(0.18, 0.22, y)
    pads = np.minimum(np.linalg.norm((V - v(0.024, 0.374, 0.32)) * v(1, 1.15, 0.6), axis=1), np.linalg.norm((V - v(-0.024, 0.374, 0.32)) * v(1, 1.15, 0.6), axis=1))
    pads = np.minimum(pads, np.linalg.norm((V - v(0, 0.352, 0.3)) * v(1, 1, 0.6), axis=1))
    muz = sstep(0.046, 0.034, pads)
    paws = sstep(0.05, 0.035, y)
    tailtip = sstep(0.575, 0.6, y) * sstep(-0.2, -0.23, z)
    m = np.clip(np.maximum.reduce([belly, chest, muz, paws, tailtip]), 0, 1)
    col = col * (1 - m[:, None]) + BELLY * m[:, None]
    # trong tai
    for s_ in (-1, 1):
        ed, (lx, ly, lz) = ear_sdf(V, s_)
        e = (ed < 0.006) * sstep(-0.004, 0.002, lz) * sstep(0.01, 0.025, ly) * sstep(0.0, 0.008, (0.04 - ly * 0.38) - np.abs(lx))
        col = col * (1 - e[:, None]) + EARIN * e[:, None]
    # mũi
    nose = sstep(0.016, 0.012, np.linalg.norm((V - v(0, 0.401, 0.336)) * v(0.9, 1.5, 1), axis=1))
    col = col * (1 - nose[:, None]) + NOSE * nose[:, None]
    # miệng chữ Y dưới mũi
    def seg(a, b):
        pa = V - a; ba = b - a; h = np.clip((pa @ ba) / (ba @ ba), 0, 1)
        return np.linalg.norm(pa - h[:, None] * ba, axis=1)
    dl = np.minimum.reduce([seg(v(0, 0.39, 0.338), v(0, 0.372, 0.338)),
                            seg(v(0, 0.372, 0.338), v(-0.018, 0.364, 0.333)),
                            seg(v(0, 0.372, 0.338), v(0.018, 0.364, 0.333))])
    ml = sstep(0.0036, 0.0022, dl)
    col = col * (1 - ml[:, None]) + LINE * ml[:, None]
    return col

def mesh(field, name):
    verts, faces, normals, _ = measure.marching_cubes(field, 0.0, spacing=(H, H, H), gradient_direction='descent')
    verts = verts + np.array([xs[0], ys[0], zs[0]], np.float32)
    normals = -normals
    return verts.astype(np.float32), faces.astype(np.int32), normals.astype(np.float32)

body = body_sdf(P)
V, F, N = mesh(body, 'body')
C = body_colors(V, N)
np.savez(f'{OUT}/bo_body.npz', v=V, f=F, c=C)
print('body', V.shape, F.shape)
sc = scarf_sdf(P, body)
V2, F2, N2 = mesh(sc, 'scarf')
np.savez(f'{OUT}/bo_scarf.npz', v=V2, f=F2)
print('scarf', V2.shape, F2.shape)
