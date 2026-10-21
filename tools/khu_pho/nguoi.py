"""Người trong khu phố Mèo Giao Bánh Mì, phong cách D "Chững chạc" (bản người).
Dựng bằng SDF (smooth union) + marching cubes, rồi Blender gắn mắt, vật liệu, render Eevee.
Dùng: python3 nguoi.py <id> <outdir> [--glb]
Toạ độ SDF theo three.js (mét, Y lên, nhìn +Z) giống mature.py của Bơ."""
import sys, math, json, numpy as np
from skimage import measure
from sdflib import v, ellipsoid, sphere, roundcone, smin, smax, chain, hexc, sstep, noise

def nrm(a): a = np.asarray(a, np.float32); return a / np.linalg.norm(a)
def rot(yaw, pitch, roll):
    cy, sy, cp, sp, cr, sr = math.cos(yaw), math.sin(yaw), math.cos(pitch), math.sin(pitch), math.cos(roll), math.sin(roll)
    Ry = np.array([[cy, 0, sy], [0, 1, 0], [-sy, 0, cy]], np.float32)
    Rx = np.array([[1, 0, 0], [0, cp, -sp], [0, sp, cp]], np.float32)
    Rz = np.array([[cr, -sr, 0], [sr, cr, 0], [0, 0, 1]], np.float32)
    return Ry @ Rx @ Rz
def box(p, c, b, r=0.0):
    q = np.abs(p - c) - (np.asarray(b, np.float32) - r)
    return np.linalg.norm(np.maximum(q, 0), axis=-1) + np.minimum(q.max(-1), 0) - r
def cyl(p, a, b, r):  # trụ tròn đầu phẳng
    ba = b - a; pa = p - a; h = (pa @ ba) / (ba @ ba)
    d_ax = np.linalg.norm(pa - h[..., None] * ba, axis=-1) - r
    d_cap = (np.abs(h - .5) - .5) * np.linalg.norm(ba)
    return np.minimum(np.maximum(d_ax, d_cap), 0) + np.linalg.norm(np.stack([np.maximum(d_ax, 0), np.maximum(d_cap, 0)], -1), axis=-1)

# ---------------------------------------------------------------- nhân vật
# build: bw vai/ngực, belly bụng, hip hông, legr tay chân to, armr tay
CHARS = {
 'coba': dict(name='Cô Ba', role='Chủ lò bánh mì', h=1.56, build=dict(bw=1.1, belly=1.22, hip=1.18, legr=1.08, armr=1.1),
   skin='#E7AE86', hair=dict(style='bun', col='#2A1D18'), top=dict(kind='baba', col='#F1E2BF'), bottom=dict(kind='pants', col='#34383F'),
   shoe='#8A3A2A', apron='#C8412F', eye=('#A06A34', '#4A2A14'), extras=['earring', 'apron'],
   pose=dict(yaw=.22, tilt=.06, nod=.05, bend=.02, armR=dict(e=(-.25, .98, .1), w=(-.2, .92, .3), n=(0, 1, 0)), armL=dict(e=(.26, .96, -.02), w=(.2, .86, .14), n=(-1, 0, 0)), prop='basket')),
 'chutu': dict(fem=False, name='Chú Tư', role='Chủ sạp báo (đơn 1)', h=1.64, build=dict(bw=.95, belly=.95, hip=.95, legr=.9, armr=.92),
   skin='#D9A07A', hair=dict(style='short', col='#8E8A86', must=True), top=dict(kind='shirt', col='#3E8C8C', sleeve='short'), bottom=dict(kind='pants', col='#5A4E44'),
   shoe='#4A3A2E', eye=('#9A6534', '#43271A'), extras=['glasses'],
   pose=dict(yaw=-.18, tilt=-.04, nod=.12, armR=dict(e=(-.24, .98, .12), w=(-.2, 1.04, .3), n=(1, 0, .2)), armL=dict(e=(.24, .98, .12), w=(.2, 1.04, .3), n=(-1, 0, .2)), prop='newspaper')),
 'bena': dict(name='Bé Na', role='Bé ở chung cư (đơn 2)', h=1.15, kid=True, build=dict(bw=.95, belly=1.05, hip=.95, legr=1.0, armr=1.0),
   skin='#EDBB95', hair=dict(style='pigtails', col='#2C1E18', tie='#F2B33D'), top=dict(kind='dress', col='#F2C14E', sleeve='short', dots='#FFF6DC'),
   bottom=dict(kind='skirt', col='#F2C14E', dots='#FFF6DC'), shoe='#D2554A', eye=('#A87038', '#4A2A14'), extras=[],
   pose=dict(yaw=.3, tilt=.12, nod=-.04, armR=dict(e=(-.18, .66, .06), w=(-.2, .8, .16), n=(1, 0, .3)), armL=dict(e=(.2, .64, .02), w=(.12, .56, .12), n=(-1, 0, 0)), prop='coin')),
 'may': dict(name='Chị Mây', role='Chủ Cà phê Mây (đơn 3)', h=1.6, build=dict(bw=.92, belly=.92, hip=1.02, legr=.92, armr=.9),
   skin='#E8B48E', hair=dict(style='ponytail', col='#3A2620'), top=dict(kind='tee', col='#F6F1E6', sleeve='short'), bottom=dict(kind='pants', col='#4D6A8A'),
   shoe='#E9E2D2', apron='#7A5236', eye=('#A06A34', '#4A2A14'), extras=['apron'],
   pose=dict(yaw=-.25, tilt=.08, nod=.02, armR=dict(e=(-.24, .98, .08), w=(-.16, 1.02, .28), n=(0, 1, 0)), armL=dict(e=(.24, .96, -.02), w=(.27, .76, .04), n=(-1, 0, 0)), prop='tray')),
 'hung': dict(fem=False, name='Anh Hùng', role='Thợ sửa xe (đơn 4)', h=1.68, build=dict(bw=1.2, belly=1.08, hip=1.05, legr=1.15, armr=1.22),
   skin='#C98C62', hair=dict(style='short', col='#1E1714', cap='#C8412F'), top=dict(kind='tee', col='#2F4A6A', sleeve='short', grease=True), bottom=dict(kind='pants', col='#2F4A6A', grease=True),
   shoe='#2E2A28', eye=('#8A5A2E', '#3A2214'), extras=['towel'],
   pose=dict(yaw=.2, tilt=-.05, nod=0, armR=dict(e=(-.28, .98, .02), w=(-.26, 1.12, .14), n=(1, 0, 0)), armL=dict(e=(.28, .95, -.03), w=(.31, .74, .03), n=(-1, 0, 0)), prop='wrench')),
 'basau': dict(name='Bà Sáu', role='Nhà bông giấy (đơn 5)', h=1.48, build=dict(bw=.95, belly=1.05, hip=1.05, legr=.9, armr=.9),
   skin='#DDA481', hair=dict(style='bun', col='#E4E0DA'), top=dict(kind='baba', col='#8C4A8A'), bottom=dict(kind='pants', col='#2E2A30'),
   shoe='#6A4A3A', eye=('#8A5A36', '#3E2416'), extras=['earring', 'glasses_round'], old=True,
   pose=dict(yaw=-.2, tilt=.06, nod=.06, bend=.16, armR=dict(e=(-.22, .94, .12), w=(-.14, .88, .3), n=(0, 1, .2)), armL=dict(e=(.22, .94, .08), w=(.12, .9, .26), n=(0, 1, .2)), prop='wateringcan')),
 'ongbay': dict(fem=False, name='Ông Bảy', role='Hàng xóm đánh cờ', h=1.6, build=dict(bw=.9, belly=.85, hip=.92, legr=.82, armr=.82),
   skin='#C99272', hair=dict(style='short', col='#EDEAE4', goatee=True), top=dict(kind='singlet', col='#F4F1EA'), bottom=dict(kind='shorts', col='#6B6A55'),
   shoe='#7A5A3A', eye=('#8A5A36', '#3E2416'), extras=[], old=True,
   pose=dict(sit=.28, yaw=.1, tilt=.1, nod=.22, bend=.3, armR=dict(e=(-.2, .9, .2), w=(-.08, .84, .36), n=(0, -1, 0)), armL=dict(e=(.2, .9, .2), w=(.13, .95, .3), n=(-.5, .2, .8)), prop='chess')),
 'ongtam': dict(fem=False, name='Ông Tám', role='Hàng xóm đánh cờ', h=1.58, build=dict(bw=1.12, belly=1.45, hip=1.12, legr=1.0, armr=1.0),
   skin='#D49A74', hair=dict(style='bald', col='#BEB8B0', must=True), top=dict(kind='shirt', col='#E7E0CF', sleeve='short', stripes='#6E8FA8'), bottom=dict(kind='pants', col='#E7E0CF', stripes='#6E8FA8'),
   shoe='#7A5A3A', eye=('#8A5A36', '#3E2416'), extras=[], old=True,
   pose=dict(sit=.28, yaw=-.15, tilt=-.08, nod=.1, bend=.12, armR=dict(e=(-.27, .92, .05), w=(-.2, .78, .24), n=(1, 0, 0)), armL=dict(e=(.26, .98, .12), w=(.24, 1.14, .2), n=(-1, 0, .3)), prop='fan')),
 'cohai': dict(name='Cô Hai', role='Chủ tiệm tạp hóa', h=1.55, build=dict(bw=1.05, belly=1.15, hip=1.12, legr=1.0, armr=1.02),
   skin='#E2A983', hair=dict(style='perm', col='#3A2420'), top=dict(kind='tee', col='#3F8A5C', sleeve='short', floral='#F2B33D'), bottom=dict(kind='pants', col='#2E3640'),
   shoe='#C8412F', eye=('#A06A34', '#4A2A14'), extras=['fannypack'],
   pose=dict(yaw=.25, tilt=.05, nod=0, armR=dict(e=(-.24, .9, .1), w=(-.12, .94, .27), n=(0, 1, .3)), armL=dict(e=(.26, .96, 0), w=(.2, .84, .06), n=(-1, 0, 0)), prop='calc')),
 'chunam': dict(fem=False, name='Chú Năm', role='Xe ôm đầu hẻm', h=1.66, build=dict(bw=1.0, belly=1.0, hip=1.0, legr=.95, armr=.95),
   skin='#C68A60', hair=dict(style='short', col='#221A16', helmet='#2E7C80'), top=dict(kind='shirt', col='#C9B48A', sleeve='long'), bottom=dict(kind='pants', col='#3D3F40'),
   shoe='#2E2A28', eye=('#8A5A2E', '#3A2214'), extras=[],
   pose=dict(yaw=-.2, tilt=.05, nod=-.03, armR=dict(e=(-.25, .96, -.04), w=(-.24, 1.18, .02), n=(1, 0, 0)), armL=dict(e=(.27, .96, -.02), w=(.3, .76, .02), n=(-1, 0, 0)), prop=None)),
}

# ---------------------------------------------------------------- khung xương
def setup(c, posed):
    h = c['h']; kid = c.get('kid', False)
    hh = h / (3.9 if kid else 5.1)            # chiều cao đầu: 1:5,5 (người lớn), 1:4 (trẻ em)
    hb = h - hh                                # tới cằm
    s = hb / 1.31                              # hệ số so với người mẫu 1,6 m
    B = c['build']
    G = dict(h=h, hh=hh, hb=hb, s=s, kid=kid, posed=posed)
    G['head_c'] = v(0, hb + hh * .37, .014 * s); G['head_r'] = v(hh * .415, hh * .48, hh * .44)
    if kid: G['head_r'] = v(hh * .43, hh * .5, hh * .45)
    sc = lambda *a: v(*a) * s
    G['Pu'] = sc(0, .92, 0); G['Ph'] = v(0, hb + .015 * s, -.01 * s)
    P = c['pose'] if posed else {}
    G['T'] = v(0, -(0.79 * s - P['sit']), 0) if posed and P.get('sit') else v(0, 0, 0)
    G['Ru'] = rot(0, P.get('bend', 0) if posed else 0, 0)
    G['Rh'] = rot(P.get('yaw', 0), P.get('nod', 0), P.get('tilt', 0)) if posed else np.eye(3, dtype=np.float32)
    if posed and c.get('old') and not P.get('sit'): G['Rh'] = rot(P.get('yaw', 0), P.get('nod', 0) - P.get('bend', 0) * .8, P.get('tilt', 0))
    if posed and P.get('sit'): G['Rh'] = rot(P.get('yaw', 0), P.get('nod', 0) - P.get('bend', 0) * .7, P.get('tilt', 0))
    bw = B['bw']
    arms = {}
    for side, key in ((1, 'armL'), (-1, 'armR')):
        sh = sc(side * .168 * bw, 1.19, 0)
        el = sc(side * .232 * bw, .965, -.015); wr = sc(side * .28 * bw, .748, .015); n = (-side, 0, 0)
        if posed and P.get(key):
            a = P[key]; el = sc(a['e'][0] * (bw if abs(a['e'][0]) > .2 else 1), *a['e'][1:]); wr = sc(*a['w']); n = a['n']
        arms[side] = (sh, el, wr, nrm(n))
    G['arms'] = arms
    legs = {}
    for side in (1, -1):
        hip = sc(side * .088 * B['hip'], .77, 0); kn = sc(side * .096, .43, .012); an = sc(side * .094, .08, -.01)
        if posed and P.get('sit'):
            hw = hip + G['T']; kn = v(side * .12 * s, P['sit'] + .16 * s, .36 * s); an = v(side * .12 * s, .075 * s, .34 * s)
            if P.get('knee'):  # ghế cao (yên xe): gối, cổ chân theo mét (y, z)
                kx = P.get('kx', .12) * s; kn = v(side * kx, *P['knee']); an = v(side * kx * 1.05, *P['ankle'])
            legs[side] = (hw, kn, an)
        else:
            LG = P.get('legs', {}).get('L' if side == 1 else 'R') if posed else None
            if LG: kn = sc(side * .096, *LG[0]); an = sc(side * .094, *LG[1])   # bước đi: (y, z) gối, cổ chân
            legs[side] = (hip + G['T'], kn + G['T'], an + G['T'])
    G['legs'] = legs
    return G

def frames(G):
    T, Pu, Ru, Ph, Rh = G['T'], G['Pu'], G['Ru'], G['Ph'], G['Rh']
    root = lambda p: p - T
    up = lambda p: (p - T - Pu) @ Ru + Pu
    head = lambda p: (up(p) - Ph) @ Rh + Ph
    upw = lambda j: Ru @ (np.asarray(j, np.float32) - Pu) + Pu + T
    headw = lambda j: upw(Rh @ (np.asarray(j, np.float32) - Ph) + Ph)
    return dict(world=lambda p: p, root=root, up=up, head=head), upw, headw

# ---------------------------------------------------------------- các bộ phận
def build(c, posed):
    G = setup(c, posed); FR, upw, headw = frames(G)
    s = G['s']; B = c['build']; hc = G['head_c']; hr = G['head_r']; kid = G['kid']
    parts = []
    def add(name, fn, mat, frame='world', k=.03, sep=False): parts.append(dict(name=name, fn=fn, mat=mat, frame=frame, k=k, sep=sep))
    sc = lambda *a: v(*a) * s
    top = c['top']; bot = c['bottom']; tk = top['kind']

    # ---- đầu (khối liền: sọ, má cằm, mũi, tai, hốc mắt, mí)
    er = v(hr[0] * .29, hr[0] * .215, hr[0] * .16) * (1.1 if kid else 1.0)
    ey = hc[1] - hr[1] * (.06 if kid else .02)
    ex = hr[0] * (.4 if kid else .37)
    def surfz(x, y):
        return hc[2] + hr[2] * math.sqrt(max(0, 1 - (x / hr[0]) ** 2 - ((y - hc[1]) / hr[1]) ** 2))
    ecs = [v(sd * ex, ey, surfz(ex, ey) - er[2] * .55) for sd in (-1, 1)]
    G['eyes'] = ecs; G['er'] = er
    lid = .14 if c.get('old') else .1
    def head_sdf(p):
        d = ellipsoid(p, hc, hr)
        jaw = ellipsoid(p, hc + v(0, -hr[1] * .33, hr[2] * .1), hr * v(.88 if not kid else .92, .6, .86))
        d = smin(d, jaw, .05 * s)
        for sd in (-1, 1):
            d = smin(d, ellipsoid(p, v(sd * hr[0] * .52, hc[1] - hr[1] * .36, hc[2] + hr[2] * .52), v(hr[0] * .38, hr[1] * .26, hr[2] * .38)), .03 * s)
            d = smin(d, ellipsoid(p, v(sd * hr[0] * .97, hc[1] - hr[1] * .1, hc[2] - hr[2] * .08), v(hr[0] * .13, hr[1] * .22, hr[2] * .17)), .012 * s)
        d = smin(d, ellipsoid(p, v(0, hc[1] - hr[1] * .2, hc[2] + hr[2] * .99), v(hr[0] * .15, hr[1] * .13, hr[2] * .14) * (.85 if kid else 1)), .012 * s)
        for i, sd in enumerate((-1, 1)):
            e_ = ecs[i]
            d = smax(d, -ellipsoid(p, e_ + v(0, 0, .004), er * v(1.05, 1.05, 1.6)), .008 * s)
            u = v(sd * -.1, 1, .12); u /= np.linalg.norm(u)
            lv = smax(ellipsoid(p, e_, er * v(1.12, 1.15, 1.25)), -((p - e_) @ u - er[1] * (1 - 2 * lid)), .003)
            d = smin(d, lv, .005 * s)
            dd = v(sd * .15, -1, .15); dd /= np.linalg.norm(dd)
            lw = smax(ellipsoid(p, e_ + v(0, -er[1] * .25, 0), er * v(1.15, 1.0, 1.2)), -((p - e_) @ dd - er[1] * (1 - 2 * .14)), .003)
            d = smin(d, lw, .006 * s)
        return d
    add('head', head_sdf, 'skin', 'head', k=.04 * s)
    # lông mày
    for sd in (-1, 1):
        bro = c['pose'].get('brow', 0) if posed else 0   # 1: cau mày (mắng), -1: nhướng lo
        pts = [v(sd * hr[0] * f, ey + er[1] * (1.85 + a), 0) for f, a in ((.15, .2 - .6 * bro), (.34, .42 - .12 * bro), (.55, .12 + .28 * bro))]
        pts = [p + v(0, 0, surfz(p[0], p[1]) + .002) for p in pts]
        rr = [.006 * s * (1.3 if c.get('old') else 1), .0068 * s, .0045 * s]
        add('brow', (lambda pts, rr: lambda p: chain(p, pts, rr, .004))(pts, rr), 'brow', 'head', k=.004)
    chest_mat_ref = lambda V: chest_mat(V)
    # cổ
    add('neck', lambda p: roundcone(p, sc(0, 1.17, -.012), v(0, G['hb'] + .04 * s, -.014 * s), .06 * s, .055 * s), 'skin', 'up', k=.04 * s)
    add('trap', lambda p: ellipsoid(p, sc(0, 1.19, -.015), sc(.155 * B['bw'], .06, .08)), chest_mat_ref, 'up', k=.04 * s)

    # ---- tóc
    hcol = c['hair']; st = hcol['style']
    def hair_sdf(p):
        x, y, z = p[..., 0], p[..., 1], p[..., 2]
        if st == 'perm':
            shell = ellipsoid(p, hc + v(0, hr[1] * .1, -hr[2] * .08), hr * v(1.2, 1.08, 1.15))
            shell = shell - .012 * s * (np.sin(x * 160) * np.sin(y * 150) * np.sin(z * 170))
        elif st == 'bald':
            shell = ellipsoid(p, hc + v(0, 0, -hr[2] * .05), hr * v(1.03, 1.02, 1.03))
            band = smax((hc[1] - hr[1] * .3) - y, y - (hc[1] + hr[1] * .12), .01)
            return smax(smax(shell, band, .01), z - (hc[2] + hr[2] * .05), .02)
        else:
            sc_ = {'short': (1.07, 1.07, 1.06), 'bun': (1.045, 1.045, 1.04), 'ponytail': (1.05, 1.05, 1.05), 'pigtails': (1.07, 1.06, 1.06)}[st]
            shell = ellipsoid(p, hc + v(0, hr[1] * .04, -hr[2] * .05), hr * v(*sc_))
        hl = {'short': .5, 'bun': .56, 'ponytail': .5, 'pigtails': .3, 'perm': .48}[st]
        fz = z - (hc[2] + hr[2] * .15); fy = (hc[1] + hr[1] * hl - hr[1] * .3 * (x / hr[0]) ** 2) - y
        if st == 'pigtails':  # mái bằng
            fy = (hc[1] + hr[1] * (hl + .08 * np.abs(x) / hr[0])) - y
        face = smax(-fz, -fy, .03 * s)
        d = smax(shell, -face, .02 * s)
        low = {'short': .25, 'bun': .45, 'ponytail': .4, 'pigtails': .5, 'perm': .6}[st]
        d = smax(d, (hc[1] - hr[1] * low) - y, .03 * s)
        if st in ('bun', 'ponytail', 'pigtails'):  # đường rẽ ngôi
            d = smax(d, -(ellipsoid(p, hc + v(0, hr[1] * 1.04, hr[2] * .3), v(.004 * s, .02 * s, hr[2] * .55))), .004)
        if st == 'bun':
            d = smin(d, ellipsoid(p, hc + v(0, hr[1] * .5, -hr[2] * .98), v(hr[0] * .42, hr[0] * .4, hr[0] * .36)), .03 * s)
        if st == 'ponytail':
            tp = [hc + v(0, hr[1] * .55, -hr[2] * .95), hc + v(0, hr[1] * .35, -hr[2] * 1.35), hc + v(.01, -hr[1] * .2, -hr[2] * 1.4), hc + v(.02, -hr[1] * .7, -hr[2] * 1.2)]
            d = smin(d, chain(p, tp, [.04 * s, .045 * s, .035 * s, .015 * s], .01), .03 * s)
        if st == 'pigtails':
            for sd in (-1, 1):
                tp = [hc + v(sd * hr[0] * .95, hr[1] * .1, -hr[2] * .3), hc + v(sd * hr[0] * 1.35, -hr[1] * .15, -hr[2] * .35), hc + v(sd * hr[0] * 1.45, -hr[1] * .6, -hr[2] * .3), hc + v(sd * hr[0] * 1.35, -hr[1] * .95, -hr[2] * .2)]
                d = smin(d, chain(p, tp, [.035 * s, .04 * s, .035 * s, .012 * s], .01), .025 * s)
        return d
    add('hair', hair_sdf, 'hair', 'head', k=.015 * s)
    if hcol.get('tie'):
        for sd in (-1, 1):
            add('tie', (lambda sd: lambda p: sphere(p, hc + v(sd * hr[0] * 1.3, hr[1] * .02, -hr[2] * .33), .022 * s))(sd), 'tie', 'head', k=.004)
    if hcol.get('must'):
        mp = [v(-hr[0] * .3, hc[1] - hr[1] * .4, 0), v(0, hc[1] - hr[1] * .33, 0), v(hr[0] * .3, hc[1] - hr[1] * .4, 0)]
        mp = [p + v(0, 0, hc[2] + hr[2] * .96) for p in mp]
        add('must', lambda p: chain(p, mp, [.008 * s, .012 * s, .008 * s], .006), 'brow', 'head', k=.006)
    if hcol.get('goatee'):
        add('goatee', lambda p: roundcone(p, hc + v(0, -hr[1] * .78, hr[2] * .72), hc + v(0, -hr[1] * 1.12, hr[2] * .72), .03 * s, .012 * s), 'hair', 'head', k=.01)
    if hcol.get('cap'):  # mũ lưỡi trai đội ngược
        def cap(p):
            dome = smax(ellipsoid(p, hc + v(0, hr[1] * .12, -hr[2] * .02), hr * v(1.1, 1.0, 1.1)), (hc[1] + hr[1] * .3) - p[..., 1], .01)
            brim = ellipsoid(p, hc + v(0, hr[1] * .38, -hr[2] * 1.1), v(hr[0] * .7, .008 * s, hr[2] * .5))
            return smin(dome, brim, .01)
        add('cap', cap, 'hat', 'head', k=.006)
    if hcol.get('helmet'):  # nón bảo hiểm nửa đầu
        def helm(p):
            dome = smax(ellipsoid(p, hc + v(0, hr[1] * .08, -hr[2] * .02), hr * v(1.16, 1.08, 1.16)), (hc[1] + hr[1] * .2) - p[..., 1], .01)
            vis = ellipsoid(p, hc + v(0, hr[1] * .3, hr[2] * 1.05), v(hr[0] * .7, .008 * s, hr[2] * .25))
            return smin(dome, vis, .01)
        add('helmet', helm, 'hat', 'head', k=.006)

    if hcol.get('nonla'):  # nón lá: vỏ nón mỏng, đường kính 0,42 m, cao 0,16 m, có quai
        nb = hc + v(0, hr[1] * .55, -hr[2] * .04); NR, NH = .21 * max(s, .9), .15 * max(s, .9)
        def nonla_sdf(p, nb=nb):
            q = p - nb; r = np.linalg.norm(q[..., [0, 2]], axis=-1); y = q[..., 1]
            ca_ = NR / math.hypot(NR, NH)
            d = np.abs(y - NH * (1 - r / NR)) * ca_ - .004
            return smax(d, r - NR, .004)
        add('nonla', nonla_sdf, 'nonla', 'head', k=.002)
        for sd in (-1, 1):
            add('quai', (lambda sd: lambda p: chain(p, [nb + v(sd * hr[0] * .95, .0, 0), hc + v(sd * hr[0] * .8, -hr[1] * .7, hr[2] * .2), hc + v(0, -hr[1] * 1.05, hr[2] * .45)], [.003 * s] * 3, .002))(sd), 'nonla2', 'head', k=.001)
    # ---- thân
    bw, bel, hip = B['bw'], B['belly'], B['hip']
    def chest_mat(V):
        x, y, z = V[:, 0], V[:, 1], V[:, 2]
        m = np.full(len(V), 'top', object)
        u_ = np.clip(1 - (x / (.075 * s)) ** 2, 0, 1)
        neck_open = (((y > (1.21 * s - .035 * s * u_)) & (z > 0)) | (y > 1.225 * s)) & (np.abs(x) < .075 * s)
        if tk == 'shirt': neck_open = (y > 1.13 * s - np.abs(x) * .3) & (np.abs(x) < .06 * s) & (z > .05 * s)
        if tk == 'singlet': neck_open |= (np.abs(x) > .1 * bw * s) & (y > 1.06 * s) | ((y > 1.15 * s) & (np.abs(x) < .09 * s) & (z > 0))
        m[neck_open] = 'skin'
        return m
    add('chest', lambda p: ellipsoid(p, sc(0, 1.065, 0), sc(.155 * bw, .17, .105)), chest_mat, 'up', k=.05 * s)
    add('belly', lambda p: ellipsoid(p, sc(0, .95, .012 * (bel - 1) * 4), sc(.14 * max(bel, bw * .95), .13, .102 * bel)), 'top', 'up', k=.05 * s)
    def pelvis_mat(V):
        return np.full(len(V), 'skirt' if bot['kind'] == 'skirt' else 'bottom', object)
    add('pelvis', lambda p: ellipsoid(p, sc(0, .83, 0), sc(.148 * hip, .11, .105 * max(1, bel * .9))), pelvis_mat, 'root', k=.05 * s)
    # vạt áo phủ qua quần
    hem_y = {'baba': .76, 'tee': .82, 'shirt': .82, 'singlet': .84, 'dress': .84}[tk]
    add('hem', lambda p: ellipsoid(p, sc(0, hem_y + .04, .01 * (bel - 1) * 3), sc(.152 * max(hip, bel), .06, .114 * max(1, bel * .95))), 'top', 'root' if hem_y < .8 else 'up', k=.012 * s)
    if tk == 'shirt':  # cổ áo
        add('collar', lambda p: smax(roundcone(p, sc(0, 1.18, -.02), sc(0, 1.24, -.02), .075 * s, .064 * s), -roundcone(p, sc(0, 1.15, -.02), sc(0, 1.3, -.02), .058 * s, .05 * s), .005), 'top', 'up', k=.006)
    if bot['kind'] == 'skirt':
        add('skirt', lambda p: roundcone(p, sc(0, .86, 0), sc(0, .6, .01), .15 * s, .2 * s), 'skirt', 'root', k=.02 * s)

    # ---- tay
    sleeve = top.get('sleeve', 'long' if tk == 'baba' else 'none')
    for side, (sh, el, wr, n) in G['arms'].items():
        ar = B['armr']
        add('delt', (lambda sh: lambda p: sphere(p, sh + v(-np.sign(sh[0]) * .016 * s, -.022 * s, -.005 * s), .04 * ar * s))(sh), 'top' if tk != 'singlet' else 'skin', 'up', k=.055 * s)
        add('arm', (lambda sh, el, wr: lambda p: chain(p, [sh, el, wr], [.045 * ar * s, .035 * ar * s, .029 * ar * s], .02))(sh, el, wr), 'skin', 'up', k=.03 * s)
        if sleeve == 'short':
            e2 = sh + (el - sh) * .5
            add('sleeve', (lambda sh, e2: lambda p: roundcone(p, sh, e2, .056 * ar * s, .05 * ar * s))(sh, e2), 'top', 'up', k=.008)
        elif sleeve == 'long':
            w2 = el + (wr - el) * .82
            fl = 1.22 if tk == 'baba' else 1.0
            add('sleeve', (lambda sh, el, w2: lambda p: chain(p, [sh, el, w2], [.052 * ar * s, .044 * ar * s, .038 * ar * s * fl], .02))(sh, el, w2), 'top', 'up', k=.008)
        # bàn tay: lòng bàn tay + 3 ngón + ngón cái, bo tròn
        d = nrm(wr - el); nn = n - d * (n @ d); nn = nrm(nn) if np.linalg.norm(nn) > 1e-3 else nrm(np.cross(d, v(0, 0, 1)))
        sd_ = nrm(np.cross(d, nn)); fwd = v(0, 0, 1) if not (posed and c['pose'].get('sit')) else v(0, .3, 1)
        tdir = sd_ if sd_ @ fwd > 0 else -sd_
        hs = s * (1.25 if kid else 1.15) * (.95 + .1 * ar)
        pc = wr + d * .045 * hs
        def hand(p, pc=pc, d=d, nn=nn, sd_=sd_, tdir=tdir, hs=hs):
            q = p - pc; loc = np.stack([q @ sd_, q @ d, q @ nn], -1)
            dd = ellipsoid(loc, v(0, 0, 0), v(.036, .042, .017) * hs)
            for off in (-.022, 0, .022):
                b = pc + d * .028 * hs + sd_ * off * hs - nn * .004 * hs
                t = b + d * (.042 - abs(off) * .35) * hs - nn * .012 * hs
                dd = smin(dd, roundcone(p, b, t, .0115 * hs, .0105 * hs), .008 * hs)
            tb = pc + tdir * .025 * hs - d * .01 * hs; tt = tb + (tdir * .7 + d * .7 - nn * .1) * .035 * hs
            dd = smin(dd, roundcone(p, tb, tt, .013 * hs, .011 * hs), .01 * hs)
            return dd
        add('hand', hand, 'skin', 'up', k=.015 * s)

    # ---- chân
    for side, (hp, kn, an) in G['legs'].items():
        lr = B['legr']
        add('leg', (lambda hp, kn, an: lambda p: chain(p, [hp, kn, an], [.078 * lr * s, .055 * lr * s, .037 * lr * s], .03))(hp, kn, an), 'skin', 'world', k=.04 * s)
        cm = kn + (an - kn) * .3 + v(0, 0, -.012 * s)
        add('calf', (lambda cm, kn, an: lambda p: ellipsoid(p, cm, v(.05 * lr * s, .095 * s, .052 * lr * s)))(cm, kn, an), 'skin', 'world', k=.03 * s)
        if bot['kind'] in ('pants', 'shorts'):
            if bot['kind'] == 'pants':
                a2 = kn + (an - kn) * .9
                add('pant', (lambda hp, kn, a2: lambda p: chain(p, [hp, kn, a2], [.09 * lr * s, .07 * lr * s, .058 * lr * s], .03))(hp, kn, a2), 'bottom', 'world', k=.01)
            else:
                k2 = hp + (kn - hp) * .82
                add('pant', (lambda hp, k2: lambda p: roundcone(p, hp, k2, .094 * lr * s, .078 * lr * s))(hp, k2), 'bottom', 'world', k=.01)
        # bàn chân + dép
        fdir = nrm(v(0, 0, 1) + v(side * .12, 0, 0)); fc = an + v(0, -an[1] + .034 * s, 0) + fdir * .05 * s
        add('foot', (lambda fc: lambda p: ellipsoid(p, fc, v(.05 * s, .036 * s, .105 * s)))(fc), 'skin' if c.get('sandal', True) else 'shoe', 'world', k=.025 * s)
        add('sole', (lambda fc: lambda p: ellipsoid(p, fc + v(0, -.02 * s, .004 * s), v(.06 * s, .016 * s, .118 * s)))(fc), 'shoe', 'world', k=.004)
        add('strap', (lambda fc: lambda p: smax(ellipsoid(p, fc + v(0, -.004 * s, .03 * s), v(.05 * s, .036 * s, .028 * s)), -(p[..., 1] - (fc[1] - .01 * s)), .004))(fc), 'shoe', 'world', k=.004)

    # ---- phụ kiện trên người
    ex_ = c.get('extras', [])
    if 'apron' in ex_:
        aw = .16 * max(bel, hip)
        def apron(p):
            cone = roundcone(p, sc(0, .93, .012 * (bel - 1) * 4 + .004), sc(0, .48, .03), (.14 * max(bel, bw * .95) + .012) * s, aw * s * 1.2)
            shell = np.abs(cone + .004 * s) - .006 * s
            cut = np.maximum.reduce([.0 * s - p[..., 2], p[..., 1] - .93 * s, .47 * s - p[..., 1], np.abs(p[..., 0]) - (aw * .92 + .1 * (.95 - p[..., 1] / s) * .3) * s])
            return smax(shell, cut, .02 * s)
        add('apron', apron, 'apron', 'root', k=.004)
        add('apronband', lambda p: smax(np.abs(ellipsoid(p, sc(0, .93, .012 * (bel - 1) * 4), sc(.14 * max(bel, bw * .95) + .008, .2, .102 * bel + .008))) - .005 * s, np.abs(p[..., 1] - .925 * s) - .013 * s, .003), 'apron', 'root', k=.003)
        add('pocket', lambda p: box(p, sc(-.05, .66, .0) + v(0, 0, .0), sc(.06, .05, .2), .01 * s) if False else smax(np.abs(roundcone(p, sc(0, .93, .012 * (bel - 1) * 4 + .004), sc(0, .48, .03), (.14 * max(bel, bw * .95) + .012) * s, aw * s * 1.2) - .006 * s) - .004 * s, np.maximum.reduce([-p[..., 2], np.abs(p[..., 1] - .66 * s) - .05 * s, np.abs(p[..., 0] + .06 * s) - .06 * s]), .012), 'apron2', 'root', k=.003)
    if 'towel' in ex_:
        sh = G['arms'][1][0]
        add('towel', lambda p: smax(np.abs(ellipsoid(p, sh + v(-.02 * s, -.02 * s, 0), v(.08 * s, .09 * s, .11 * s))) - .007 * s, (sh[1] - .1 * s) - p[..., 1], .01), 'towel', 'up', k=.004)
    if 'fannypack' in ex_:
        add('pack', lambda p: ellipsoid(p, sc(.03, .84, .13 * bel), sc(.09, .05, .04)), 'pack', 'root', k=.006)
        add('packstrap', lambda p: smax(np.abs(ellipsoid(p, sc(0, .85, 0), sc(.152 * hip, .4, .11 * bel))) - .004 * s, np.abs(p[..., 1] - .85 * s) - .012 * s, .003), 'pack', 'root', k=.002)
    if 'earring' in ex_:
        for sd in (-1, 1):
            add('earring', (lambda sd: lambda p: sphere(p, v(sd * hr[0] * 1.0, hc[1] - hr[1] * .3, hc[2] - hr[2] * .05), .009 * s))(sd), 'gold', 'head', k=.002)

    # ---- đồ cầm tay (mesh riêng, chỉ ở dáng nhân vật)
    pr = c['pose'].get('prop') if posed else None
    WR = {sd: G['arms'][sd][2] for sd in (1, -1)}
    mid = (WR[1] + WR[-1]) / 2
    if pr == 'newspaper':
        def paper(p):
            q = p - mid - v(0, .04 * s, .03 * s)
            ang = -.35; ca, sa = math.cos(ang), math.sin(ang)
            q = np.stack([q[..., 0], q[..., 1] * ca - q[..., 2] * sa, q[..., 1] * sa + q[..., 2] * ca], -1)
            bend = .6 * q[..., 0] ** 2 / s
            return box(np.stack([q[..., 0], q[..., 1], q[..., 2] + bend], -1), v(0, 0, 0), v(.2 * s, .14 * s, .003 * s), .002)
        add('paper', paper, 'paper', 'up', sep=True)
    if pr == 'basket':  # rổ bánh mì
        w = WR[-1]; bc = w + v(.06 * s, .03 * s, .02 * s)
        def basket(p):
            b = smax(np.abs(ellipsoid(p, bc, sc(.13, .07, .09))) - .006 * s, p[..., 1] - bc[1], .005)
            return b
        add('basket', basket, 'wicker', 'up', sep=True)
        for i in range(3):
            add('bread', (lambda i: lambda p: roundcone(p, bc + sc(-.09, .01 + .01 * i, -.03 + .03 * i), bc + sc(.09, .02 + .01 * i, .0 + .02 * i), .025 * s, .022 * s))(i), 'bread', 'up', sep=True, k=.002)
        add('handle', lambda p: smax(np.abs(np.linalg.norm((p - bc)[..., :2] * v(1, .75), axis=-1) - .13 * s) - .006 * s, np.maximum(np.abs((p - bc)[..., 2]) - .008 * s, bc[1] - p[..., 1]), .003), 'wicker', 'up', sep=True)
    if pr in ('loaf', 'loaf2'):  # ổ bánh mì trên tay
        lc = (mid + v(0, .03 * s, .02 * s)) if pr == 'loaf2' else (WR[-1] + nrm(WR[-1] - G['arms'][-1][1]) * .07 * s + v(0, .035 * s, 0))
        add('loaf', lambda p: roundcone(p, lc + sc(-.13, 0, 0), lc + sc(.13, .01, 0), .036 * s, .032 * s), 'bread', 'up', sep=True, k=.002)
        add('bag', lambda p: smax(box(p, lc + sc(0, -.005, 0), sc(.06, .045, .045), .006), -box(p, lc + sc(0, .04, 0), sc(.07, .02, .05), .0), .003), 'paper', 'up', sep=True)
    if pr == 'ropebasket':  # giỏ nhựa thòng dây từ ban công
        bc = mid + v(0, -.62 * s, .1 * s)
        add('rope', lambda p: roundcone(p, mid + v(0, .01 * s, .01 * s), bc + v(0, .1 * s, 0), .006 * s, .006 * s), 'wicker', 'up', sep=True)
        add('basket', lambda p: smax(np.abs(roundcone(p, bc, bc + v(0, .09 * s, 0), .07 * s, .09 * s)) - .006 * s, p[..., 1] - bc[1] - .085 * s, .004), 'tray', 'up', sep=True)
    if pr == 'tray':
        w = WR[-1]; tc = w + v(0, .025 * s, 0)
        add('tray', lambda p: cyl(p, tc, tc + v(0, .012 * s, 0), .14 * s), 'tray', 'up', sep=True)
        for dx, dz in ((-.06, -.03), (.05, -.02), (0, .06)):
            cc = tc + sc(dx, .012, dz)
            add('cup', (lambda cc: lambda p: roundcone(p, cc + v(0, .02 * s, 0), cc + v(0, .1 * s, 0), .026 * s, .032 * s))(cc), 'coffee', 'up', sep=True, k=.002)
    if pr == 'wrench':
        w = WR[-1]
        add('wrench', lambda p: smin(roundcone(p, w + sc(0, -.06, .0), w + sc(0, .16, 0), .012 * s, .012 * s), smax(sphere(p, w + sc(0, .19, 0), .035 * s), -sphere(p, w + sc(0, .215, 0), .022 * s), .004), .01), 'metal', 'up', sep=True)
    if pr == 'wateringcan':
        cc = mid + v(0, -.08 * s, .05 * s)
        def can(p):
            b = roundcone(p, cc, cc + v(0, .16 * s, 0), .09 * s, .075 * s)
            b = smin(b, roundcone(p, cc + sc(0, .04, .06), cc + sc(0, .2, .26), .022 * s, .012 * s), .02 * s)
            b = smin(b, smax(np.abs(np.linalg.norm((p - cc - sc(0, .17, -.02))[..., 1:], axis=-1) - .07 * s) - .008 * s, np.abs((p - cc)[..., 0]) - .012 * s, .003), .01)
            return b
        add('can', can, 'can', 'up', sep=True)
    if pr == 'chess':
        w = WR[1]
        add('piece', lambda p: cyl(p, w + sc(.0, .01, .02), w + sc(0, .026, .02), .028 * s), 'chesspiece', 'up', sep=True)
    if pr == 'fan':
        w = WR[1]
        def fan(p):
            q = p - w - sc(0, .06, .02)
            r_ = np.linalg.norm(q[..., :2], axis=-1); a = np.arctan2(q[..., 0], q[..., 1])
            return smax(smax(r_ - .19 * s, np.abs(q[..., 2]) - .003 * s, .002), np.abs(a) - 1.0, .01)
        add('fan', fan, 'fan', 'up', sep=True)
        add('fanhandle', lambda p: roundcone(p, w + sc(0, -.03, .02), w + sc(0, .07, .02), .008 * s, .008 * s), 'wood', 'up', sep=True)
    if pr == 'coin':
        w = WR[1]
        add('coin', lambda p: cyl(p, w + sc(0, .03, .02), w + sc(.0, .034, .02), .016 * s), 'gold', 'up', sep=True)
    if pr == 'calc':  # bàn tính / máy tính bỏ túi
        w = WR[-1]
        add('calc', lambda p: box(p, w + sc(.02, .03, .04), sc(.04, .008, .06), .004), 'calc', 'up', sep=True)
    if posed and c['pose'].get('sit'):  # ghế nhựa đỏ thấp
        seat = c['pose']['sit']
        def stool(p):
            top_ = box(p, v(0, seat - .085, -.02 * s), v(.16, .015, .16), .01)
            for sx in (-1, 1):
                for sz in (-1, 1):
                    top_ = smin(top_, roundcone(p, v(sx * .13, seat - .095, sz * .13 - .02 * s), v(sx * .16, .01, sz * .16 - .02 * s), .018, .02), .01)
            return top_
        add('stool', stool, 'stool', 'world', sep=True)
    return parts, G, FR, headw

# ---------------------------------------------------------------- màu
def palette(c):
    P = dict(skin=c['skin'], hair=c['hair']['col'], brow=c['hair']['col'] if c['hair']['style'] != 'bald' else '#9C958E', top=c['top']['col'], bottom=c['bottom']['col'], skirt=c['bottom']['col'],
             shoe=c['shoe'], apron=c.get('apron', '#7A5236'), apron2=c.get('apron2', '#A93424' if c.get('apron') == '#C8412F' else '#5E3E28'), tie=c['hair'].get('tie', '#F2B33D'), hat=c['hair'].get('cap') or c['hair'].get('helmet') or '#333333',
             towel='#E9E2D2', pack='#3A2C26', gold='#E0B040', paper='#EDE6D3', wicker='#C99A5A', bread='#D98E2B', tray='#B8BEC0', glass='#D8E6E4', coffee='#9A6A44',
             metal='#9AA3A6', can='#3F8A5C', chesspiece='#E8D9B5', fan='#D8B47A', wood='#8A5A30', calc='#3D3F40', stool='#C8412F', nonla='#E2CC94', nonla2='#8A6A40')
    P.update(EXTRA_PAL)
    return P
EXTRA_PAL = {}
def lin(c): return np.where(c <= .04045, c / 12.92, ((c + .055) / 1.055) ** 2.4)

# ---------------------------------------------------------------- dựng lưới
def eval_pts(sel, FR, P):
    d = None
    for pt in sel:
        di = pt['fn'](FR[pt['frame']](P))
        d = di if d is None else smin(d, di, pt['k'])
    return d

def make_field(parts, G, FR, sep, H):
    """Lưới thô 2H, rồi tính lại chính xác ở bước H chỉ trong dải sát bề mặt."""
    s = G['s']; h = G['h']; Hc = 2 * H
    sel = [p for p in parts if p['sep'] == sep]
    if not sel: return None
    xs = np.arange(-.48 * s, .48 * s, Hc, dtype=np.float32); ys = np.arange(-.01, h + .12 * s, Hc, dtype=np.float32); zs = np.arange(-.36 * s, .58 * s, Hc, dtype=np.float32)
    fc = np.empty((len(xs), len(ys), len(zs)), np.float32)
    Y, Z = np.meshgrid(ys, zs, indexing='ij')
    for i0 in range(0, len(xs), 24):
        X = xs[i0:i0 + 24]
        P = np.stack(np.broadcast_arrays(X[:, None, None], Y[None], Z[None]), -1).astype(np.float32)
        fc[i0:i0 + 24] = eval_pts(sel, FR, P)
    fine = fc.repeat(2, 0).repeat(2, 1).repeat(2, 2)
    xf = xs[0] + np.arange(fine.shape[0], dtype=np.float32) * H; yf = ys[0] + np.arange(fine.shape[1], dtype=np.float32) * H; zf = zs[0] + np.arange(fine.shape[2], dtype=np.float32) * H
    idx = np.nonzero(np.abs(fine) < 2.2 * Hc)
    print('band pts', len(idx[0]), 'of', fine.size)
    CH = 1500000
    for a in range(0, len(idx[0]), CH):
        ii = tuple(x[a:a + CH] for x in idx)
        P = np.stack([xf[ii[0]], yf[ii[1]], zf[ii[2]]], -1)
        fine[ii] = eval_pts(sel, FR, P)
    return fine, (xf, yf, zf)

def mesh(field, axes, H):
    xs, ys, zs = axes
    V, F, N, _ = measure.marching_cubes(field, 0.0, spacing=(H, H, H), gradient_direction='descent')
    return (V + np.array([xs[0], ys[0], zs[0]], np.float32)).astype(np.float32), F.astype(np.int32), (-N).astype(np.float32)

def seg2(P2, a, b):
    pa = P2 - a; ba = b - a; t = np.clip((pa @ ba) / (ba @ ba), 0, 1)
    return np.linalg.norm(pa - t[:, None] * ba, axis=1)

def colorize(c, parts, G, FR, V, N, sep):
    PAL = palette(c); sel = [p for p in parts if p['sep'] == sep]
    D = np.stack([pt['fn'](FR[pt['frame']](V)) for pt in sel], 1)
    idx = D.argmin(1); Dm = D.min(1)
    mats = np.empty(len(V), object)
    tau = .0011 * G['s']; acc = np.zeros((len(V), 3), np.float32); wsum = np.zeros(len(V), np.float32)
    for i, pt in enumerate(sel):
        m = (D[:, i] - Dm) < 5 * tau
        if not m.any(): continue
        mm = pt['mat'](FR[pt['frame']](V[m])) if callable(pt['mat']) else np.full(m.sum(), pt['mat'], object)
        hard = idx[m] == i
        tmp = mats[m]; tmp[hard] = mm[hard]; mats[m] = tmp
        cc = np.stack([hexc(PAL.get(x, '#FF00FF')) for x in mm]) if len(set(mm)) > 1 else np.tile(hexc(PAL.get(mm[0], '#FF00FF')), (len(mm), 1))
        w = np.exp(-(D[m, i] - Dm[m]) / tau)
        acc[m] += cc * w[:, None]; wsum[m] += w
    col = acc / wsum[:, None]
    mix = lambda col, w, C: col * (1 - w[:, None]) + hexc(C) * w[:, None]
    top, bot = c['top'], c['bottom']
    Vu = FR['up'](V); Vr = FR['root'](V)
    for key, spec, Vs in (('top', top, Vu), ('bottom', bot, Vr), ('skirt', bot, Vr)):
        m = (mats == key)
        if not m.any(): continue
        if spec.get('stripes'):
            w = sstep(.3, .6, np.sin(Vs[:, 0] * 90 + Vs[:, 2] * 5)) * m
            col = mix(col, w, spec['stripes'])
        if spec.get('dots'):
            q = Vs * 24; w = sstep(.32, .26, np.linalg.norm(q - np.round(q), axis=1)) * m
            col = mix(col, w, spec['dots'])
        if spec.get('floral'):
            n1 = noise(Vs * 1.6); n2 = noise(Vs * 1.6 + 3.1)
            col = mix(col, sstep(.55, .7, n1) * m, spec['floral']); col = mix(col, sstep(.6, .75, n2) * m, '#E9E2D2')
        if spec.get('grease'):
            col = mix(col, sstep(.5, .8, noise(Vs * .9 + 1.7)) * m * .45, '#1E2228')
    if top['kind'] == 'baba':  # hàng nút áo bà ba
        m = mats == 'top'; q = Vu
        for yb in np.arange(.82, 1.14, .075):
            col = mix(col, (np.linalg.norm((q - v(0, yb, 0) * G['s'])[:, :2], axis=1) < .008 * G['s']) * (q[:, 2] > 0) * m, '#B89A60')
    if top['kind'] == 'shirt':
        m = mats == 'top'; q = Vu
        for yb in np.arange(.86, 1.12, .07):
            col = mix(col, (np.linalg.norm((q - v(0, yb, 0) * G['s'])[:, :2], axis=1) < .006 * G['s']) * (q[:, 2] > 0) * m, '#F4F1EA')
    # sợi tóc
    hm = (mats == 'hair')
    if hm.any():
        Vh_ = FR['head'](V)
        st_ = sstep(.2, .9, np.sin(Vh_[:, 0] * 420 / G['s'] + noise(Vh_ * 3) * 4 + Vh_[:, 1] * 60)) * hm
        col = mix(col, st_ * .18, '#000000' if c['hair']['col'] < '#888888' else '#8A847C')
        col = mix(col, sstep(.7, .95, np.sin(Vh_[:, 0] * 300 / G['s'] + 1.3 + noise(Vh_ * 2) * 3)) * hm * .08, '#FFFFFF')
    # mặt: miệng cười, má hồng
    if not sep:
        Vh = FR['head'](V); hc, hr = G['head_c'], G['head_r']; s = G['s']
        Rt = G['Ru'] @ G['Rh']; Nh = N @ Rt
        front = (Nh[:, 2] > .25) & (Vh[:, 2] > hc[2] + hr[2] * .45) & (mats == 'skin')
        hi_ = [i for i, p in enumerate(sel) if p['name'] == 'head']
        if hi_: front &= (idx == hi_[0])   # chỉ tô lên đầu, không lem sang bàn tay đưa lên miệng
        my = hc[1] - hr[1] * .55
        mx = hr[0] * .3
        P2 = Vh[:, :2]; mo = c['pose'].get('mouth', 'smile') if G.get('posed') else 'smile'
        if mo in ('smile', 'frown'):
            sg = 1 if mo == 'smile' else -.8
            pts = [v(-mx, my + .012 * s * sg), v(-mx * .5, my - .006 * s * sg), v(0, my - .01 * s * sg), v(mx * .5, my - .006 * s * sg), v(mx, my + .012 * s * sg)]
            if mo == 'frown': pts = [p + v(0, -.012 * s) for p in pts]
            dl = np.minimum.reduce([seg2(P2, pts[i], pts[i + 1]) for i in range(4)])
            col = mix(col, sstep(.0045 * s, .0025 * s, dl) * front, '#6A2E26')
        else:  # miệng mở: o (suỵt, chu môi), open (reo, cười há), shout (mắng)
            rx, ry, cy_ = dict(o=(mx * .22, .011 * s, my - .008 * s), open=(mx * .8, .026 * s, my - .01 * s), shout=(mx * .55, .03 * s, my - .014 * s))[mo]
            q2 = (P2 - v(0, cy_)) / v(rx, ry); r2 = np.linalg.norm(q2, axis=1)
            inside = sstep(1.0, .85, r2)
            if mo == 'open': inside = inside * (q2[:, 1] < .35)   # hình chữ D: mép trên phẳng
            col = mix(col, sstep(1.25, 1.05, r2) * front * .5, '#B85A50')
            col = mix(col, inside * front, '#5A1E1C')
            col = mix(col, inside * sstep(-.2, -.6, q2[:, 1]) * front * (0 if mo == 'o' else .9), '#C9645A')   # lưỡi
            if mo != 'o': col = mix(col, inside * sstep(.55, .75, q2[:, 1]) * front, '#F4EFE6')   # răng trên
        lip = sstep(.012 * s, .004 * s, np.linalg.norm((P2 - v(0, my - .016 * s)) * v(.55, 1), axis=1)) * front
        col = mix(col, lip * .35, '#C46A60')
        for sd in (-1, 1):
            bc_ = v(sd * hr[0] * .52, hc[1] - hr[1] * .3)
            col = mix(col, sstep(.04 * s, .012 * s, np.linalg.norm(P2 - bc_, axis=1)) * front * (.22 if not G['kid'] else .32), '#E07A6A')
        # viền mi trên (đậm cho nữ, nhạt cho nam)
        Vh3 = Vh; fem = c.get('fem', True)
        for e_ in G['eyes']:
            q = (Vh3 - e_) / G['er']; r_ = np.linalg.norm(q[:, :2], axis=1)
            band = sstep(.86, .96, r_) * sstep(1.16, 1.04, r_) * sstep(-.1, .3, q[:, 1]) * (Vh3[:, 2] > e_[2] - G['er'][2] * .2) * (mats == 'skin')
            col = mix(col, band * (.75 if fem else .4), '#3A2418')
        if c.get('old'):
            for sd in (-1, 1):  # nếp cười
                a = v(sd * hr[0] * .3, hc[1] - hr[1] * .25); b = v(sd * hr[0] * .38, hc[1] - hr[1] * .5)
                col = mix(col, sstep(.004 * s, .0015 * s, seg2(P2, a, b)) * front * .35, '#8A5040')
    return col, mats

# ---------------------------------------------------------------- Blender
GROUP = dict(skin='skin', hair='hair', brow='hair', hat='hard', shoe='hard', gold='metal', metal='metal', glass='glass', tray='metal', stool='hard', calc='hard', can='hard', chesspiece='hard', coffee='glass')
# ---------------------------------------------------------------- tư thế nhận bánh (gói giao bánh Thứ Hai)
GIAO = {
 'chutu': dict(yaw=-.1, nod=.32, bend=.34, armR=dict(e=(-.2, 1.1, .2), w=(-.16, 1.02, .42), n=(0, 1, 0)), armL=dict(e=(.24, .96, -.02), w=(.27, .76, .06), n=(-1, 0, 0)), prop='loaf'),
 'bena': dict(yaw=.05, nod=.42, tilt=.06, bend=.14, armR=dict(e=(-.2, 1.0, .2), w=(-.05, 1.04, .36), n=(1, 0, 0)), armL=dict(e=(.2, 1.0, .2), w=(.05, 1.04, .36), n=(-1, 0, 0)), prop='ropebasket'),
 'may': dict(yaw=.1, nod=.2, tilt=.06, bend=.12, armR=dict(e=(-.22, .96, .16), w=(-.12, .92, .38), n=(0, 1, 0)), armL=dict(e=(.22, .96, .16), w=(.12, .92, .38), n=(0, 1, 0)), prop='loaf2'),
 'hung': dict(sit=.28, yaw=-.2, nod=.25, bend=.38, armR=dict(e=(-.3, 1.02, .2), w=(-.36, .9, .42), n=(0, 1, 0)), armL=dict(e=(.25, .95, .12), w=(.2, .86, .32), n=(-1, 0, 0)), prop='loaf'),
 'basau': dict(sit=.42, yaw=.08, nod=.18, tilt=-.05, bend=.14, armR=dict(e=(-.2, 1.0, .2), w=(-.1, .98, .4), n=(0, 1, 0)), armL=dict(e=(.2, 1.0, .2), w=(.1, .98, .4), n=(0, 1, 0)), prop='loaf2'),
}

POSE_ONLY = [False]; SUF = ['']
HOOKS = []   # hàm(scn, coll, G, headw, B) gắn thêm vật vào dáng nhân vật
def run(cid, out, glb=False):
    c = CHARS[cid]; H = .003 * (.8 if c.get('kid') else 1.0)
    import bpy
    from mathutils import Vector, Matrix, Quaternion
    bpy.ops.wm.read_factory_settings(use_empty=True); scn = bpy.context.scene
    def B(p): return Vector((float(p[0]), float(-p[2]), float(p[1])))
    def lin4(h, a=1.0): cc = lin(hexc(h)); return (*cc, a)
    def mat_group(name, kind):
        m = bpy.data.materials.new(name)
        if m.node_tree is None: m.use_nodes = True
        nt = m.node_tree; bs = nt.nodes['Principled BSDF']
        a = nt.nodes.new('ShaderNodeVertexColor'); a.layer_name = 'Col'; nt.links.new(a.outputs['Color'], bs.inputs['Base Color'])
        r = dict(skin=.55, cloth=.9, hair=.5, hard=.5, metal=.38, glass=.1)[kind]
        bs.inputs['Roughness'].default_value = r
        bs.inputs['Sheen Weight'].default_value = dict(skin=.25, cloth=.8, hair=.4).get(kind, 0)
        bs.inputs['Specular IOR Level'].default_value = dict(skin=.35, cloth=.2, hair=.45).get(kind, .5)
        if kind == 'metal': bs.inputs['Metallic'].default_value = .85
        if kind == 'glass': bs.inputs['Coat Weight'].default_value = .5
        return m
    KINDS = ['skin', 'cloth', 'hair', 'hard', 'metal', 'glass']
    MATS = {k: mat_group('M_' + k, k) for k in KINDS}
    objs = {}
    for posed in ((True,) if POSE_ONLY[0] else (False, True)):
        parts, G, FR, headw = build(c, posed)
        coll = bpy.data.collections.new('Pose' if posed else 'Apose'); scn.collection.children.link(coll)
        for sep in (False, True):
            r = make_field(parts, G, FR, sep, H if not sep else H)
            if r is None: continue
            field, axes = r; V, F, N = mesh(field, axes, H)
            col, mats = colorize(c, parts, G, FR, V, N, sep)
            print(cid, 'posed' if posed else 'apose', 'sep' if sep else 'body', 'tris', len(F))
            me = bpy.data.meshes.new(cid); Vb = np.stack([V[:, 0], -V[:, 2], V[:, 1]], 1)
            me.vertices.add(len(Vb)); me.vertices.foreach_set('co', Vb.ravel())
            me.loops.add(F.size); me.loops.foreach_set('vertex_index', F.ravel())
            me.polygons.add(len(F)); me.polygons.foreach_set('loop_start', np.arange(0, F.size, 3)); me.update(); me.validate()
            ca = me.color_attributes.new('Col', 'FLOAT_COLOR', 'POINT')
            ca.data.foreach_set('color', np.concatenate([lin(col), np.ones((len(col), 1))], 1).astype(np.float32).ravel())
            for k in KINDS: me.materials.append(MATS[k])
            g = np.array([KINDS.index(GROUP.get(m, 'cloth')) for m in mats])
            fm = g[F]; fi = np.where(fm[:, 0] == fm[:, 1], fm[:, 0], fm[:, 2])
            me.polygons.foreach_set('material_index', fi.astype(np.int32))
            me.polygons.foreach_set('use_smooth', [True] * len(me.polygons))
            ob = bpy.data.objects.new(cid + ('_do' if sep else '_than'), me); coll.objects.link(ob)
            md = ob.modifiers.new('Smooth', 'SMOOTH'); md.factor = .5; md.iterations = 7
            objs[(posed, sep)] = ob
        # mắt
        hc, hr = G['head_c'], G['head_r']; er = G['er']; Rt = G['Ru'] @ G['Rh']
        im = bpy.data.materials.new('Iris')
        if im.node_tree is None: im.use_nodes = True
        nt = im.node_tree; bs = nt.nodes['Principled BSDF']; a = nt.nodes.new('ShaderNodeVertexColor'); a.layer_name = 'Col'
        nt.links.new(a.outputs['Color'], bs.inputs['Base Color']); bs.inputs['Roughness'].default_value = .05; bs.inputs['Coat Weight'].default_value = 1
        hi = bpy.data.materials.new('Hi')
        if hi.node_tree is None: hi.use_nodes = True
        em = hi.node_tree.nodes.new('ShaderNodeEmission'); em.inputs['Color'].default_value = (1, 1, 1, 1)
        hi.node_tree.links.new(em.outputs[0], hi.node_tree.nodes['Material Output'].inputs['Surface'])
        for i, sd in enumerate((-1, 1)):
            e_ = G['eyes'][i]; nv = (e_ - hc) / hr ** 2; nv = nrm(nv)
            cw = headw(e_); nw = Rt @ nv; upv = Rt @ v(0, 1, 0)
            fwd = B(nw).normalized(); upB = B(upv); xr = upB.cross(fwd).normalized(); zu = fwd.cross(xr).normalized()
            q = Matrix((xr, -fwd, zu)).transposed().to_quaternion(); q = Quaternion(fwd, sd * .14) @ q
            bpy.ops.mesh.primitive_uv_sphere_add(segments=64, ring_count=32, radius=1, location=B(cw))
            o = bpy.context.active_object; o.scale = (er[0], er[2], er[1]); o.rotation_euler = q.to_euler(); bpy.ops.object.shade_smooth()
            for cl in o.users_collection: cl.objects.unlink(o)
            coll.objects.link(o)
            me = o.data; ca = me.color_attributes.new('Col', 'FLOAT_COLOR', 'POINT'); cols = []
            ic = c['eye']
            for vt in me.vertices:
                p = vt.co.normalized(); f = -p.y; rr = math.hypot(p.x, p.z)
                if f < .15: cc = lin4('#FBF8F2')
                elif rr < .36: cc = lin4('#140C08')
                elif rr < .8:
                    t_ = max(0, (rr - .36) / .44); a_, b_ = lin4(ic[0]), lin4(ic[1]); cc = tuple(a_[j] * (1 - t_) + b_[j] * t_ for j in range(3)) + (1,)
                else: cc = lin4('#2E1A10')
                cols.extend(cc)
            ca.data.foreach_set('color', cols); me.materials.append(im)
            loc = B(cw); up = q @ Vector((0, 0, 1)); rt = q @ Vector((1, 0, 0))
            for j, (off, rad) in enumerate((((.32, .3), .2), ((-.28, -.22), .12))):
                bpy.ops.mesh.primitive_uv_sphere_add(segments=16, ring_count=8, radius=er[0] * rad, location=loc + fwd * er[2] * .95 + up * er[1] * off[0] + rt * er[0] * off[1])
                h_ = bpy.context.active_object; h_.data.materials.append(hi)
                for cl in h_.users_collection: cl.objects.unlink(h_)
                coll.objects.link(h_)
        # kính
        if any(e in c.get('extras', []) for e in ('glasses', 'glasses_round')):
            gm = bpy.data.materials.new('Kinh')
            if gm.node_tree is None: gm.use_nodes = True
            gb = gm.node_tree.nodes['Principled BSDF']; gb.inputs['Base Color'].default_value = lin4('#3A2A20' if 'glasses' in c['extras'] else '#B8963E'); gb.inputs['Roughness'].default_value = .3
            if 'glasses_round' in c['extras']: gb.inputs['Metallic'].default_value = .9
            for i, sd in enumerate((-1, 1)):
                e_ = G['eyes'][i] + v(0, 0, er[2] * 1.6)
                bpy.ops.mesh.primitive_torus_add(major_radius=er[0] * 1.35, minor_radius=.0035 * G['s'], location=B(headw(e_)))
                t = bpy.context.active_object; t.scale = (1, 1, .82 if 'glasses' in c['extras'] else 1)
                M = Matrix([list(map(float, r)) for r in Rt]); conv = Matrix(((1, 0, 0), (0, 0, -1), (0, 1, 0)))
                Mb = conv @ M @ conv.inverted()
                t.rotation_euler = (Mb @ Matrix.Rotation(math.pi / 2, 3, 'X')).to_euler(); t.data.materials.append(gm)
                for cl in t.users_collection: cl.objects.unlink(t)
                coll.objects.link(t)
            a_ = headw(G['eyes'][0] + v(er[0] * 1.3, er[1] * .2, er[2] * 1.6)); b_ = headw(G['eyes'][1] + v(-er[0] * 1.3, er[1] * .2, er[2] * 1.6))
            bpy.ops.mesh.primitive_cylinder_add(radius=.003 * G['s'], depth=float(np.linalg.norm(a_ - b_)), location=B((a_ + b_) / 2))
            br = bpy.context.active_object; br.rotation_euler = (B(b_) - B(a_)).to_track_quat('Z', 'Y').to_euler(); br.data.materials.append(gm)
            for cl in br.users_collection: cl.objects.unlink(br)
            coll.objects.link(br)
        if posed:
            Gp = G
            for hk in HOOKS: hk(scn, coll, G, headw, B)
        else: Ga = G
    # ---------- bối cảnh render
    bpy.ops.mesh.primitive_plane_add(size=60); fl = bpy.context.active_object
    fm = bpy.data.materials.new('San')
    if fm.node_tree is None: fm.use_nodes = True
    fb = fm.node_tree.nodes['Principled BSDF']; fb.inputs['Base Color'].default_value = lin4('#8CBFB4'); fb.inputs['Roughness'].default_value = 1
    fl.data.materials.append(fm)
    w = bpy.data.worlds.new('W'); scn.world = w
    if w.node_tree is None: w.use_nodes = True
    w.node_tree.nodes['Background'].inputs['Color'].default_value = lin4('#9CCBC1'); w.node_tree.nodes['Background'].inputs['Strength'].default_value = .55
    def light(name, kind, loc, target, power, size=1.0, color=(1, 1, 1)):
        l = bpy.data.lights.new(name, kind); l.energy = power; l.color = color
        if kind == 'AREA': l.size = size
        if kind == 'SUN': l.angle = .25
        o = bpy.data.objects.new(name, l); scn.collection.objects.link(o); o.location = loc
        o.rotation_euler = (Vector(target) - Vector(loc)).to_track_quat('-Z', 'Y').to_euler()
    hh = c['h']
    light('Key', 'SUN', (2.4, -2.4, 4.0), (0, 0, hh * .4), 1.7, color=(1, .97, .92))
    light('Fill', 'AREA', (-3, -1.6, 2.2), (0, 0, hh * .5), 110 * hh, 3.0, (.9, .95, 1))
    light('Rim', 'AREA', (-.6, 3.2, 2.6), (0, 0, hh * .6), 200 * hh, 2.0)
    scn.render.engine = 'BLENDER_EEVEE'
    try: scn.eevee.taa_render_samples = 32
    except Exception: pass
    scn.view_settings.view_transform = 'Standard'
    cd = bpy.data.cameras.new('Cam'); cam = bpy.data.objects.new('Cam', cd); scn.collection.objects.link(cam); scn.camera = cam
    # Bơ để so tỉ lệ
    bo_coll = bpy.data.collections.new('Bo'); scn.collection.children.link(bo_coll)
    bpy.ops.import_scene.gltf(filepath='chung2.glb')
    for o in list(bpy.context.selected_objects):
        for cl in o.users_collection: cl.objects.unlink(o)
        bo_coll.objects.link(o)
    bo_root = bpy.data.objects.new('BoRoot', None); scn.collection.objects.link(bo_root)
    for o in bo_coll.objects:
        if o.parent is None: o.parent = bo_root
    meta = dict(id=cid, name=c['name'], role=c['role'], h=c['h'])
    if POSE_ONLY[0]: bpy.data.collections.new('Apose'); Ga = Gp
    ca_, cp_ = bpy.data.collections['Apose'], bpy.data.collections['Pose']
    def show(coll, on):
        linked = coll.name in scn.collection.children
        if on and not linked: scn.collection.children.link(coll)
        if not on and linked: scn.collection.children.unlink(coll)
    if not POSE_ONLY[0]:
        # 1) xoay vòng: trước, ngang, sau (ortho) + Bơ
        show(cp_, False); show(ca_, True); show(bo_coll, True)
        gap = .62 * hh / 1.6 + .25
        inst = []
        show(ca_, False)
        for i, ang in enumerate((0, math.pi / 2, math.pi)):
            e = bpy.data.objects.new(f'I{i}', None); e.instance_type = 'COLLECTION'; e.instance_collection = ca_
            e.location = ((i - 1) * gap * 1.25, 0, 0); e.rotation_euler = (0, 0, ang); scn.collection.objects.link(e); inst.append(e)
        bo_root.location = (1.9 * gap * 1.25, 0, 0); bo_root.rotation_euler = (0, 0, .5)
        W = 3 * gap * 1.25 + 1.0; Hh = hh + .3
        cd.type = 'ORTHO'; cd.ortho_scale = max(W, Hh * 1.9); cx = (gap * 1.25 * .45)
        scn.render.resolution_x = 1500; scn.render.resolution_y = int(1500 * Hh / max(W, Hh * 1.9) * 1.0) + 2
        cd.ortho_scale = max(W, Hh * 1.9)
        scn.render.resolution_y = int(scn.render.resolution_x * Hh / cd.ortho_scale)
        cam.location = (cx, -6, Hh / 2 - .05); cam.rotation_euler = (math.pi / 2, 0, 0)
        scn.render.filepath = f'{out}/{cid}_xoay.png'; bpy.ops.render.render(write_still=True)
        meta['turn'] = dict(ortho=cd.ortho_scale, cx=cx, cy=Hh / 2 - .05, w=scn.render.resolution_x, h=scn.render.resolution_y, xs=[(i - 1) * gap * 1.25 for i in range(3)], bo=1.9 * gap * 1.25)
        # khớp xương (dáng A) để vẽ sơ đồ
        G = Ga; J = {}
        J['hips'] = G['Pu'] * v(1, .86, 1); J['spine'] = G['Pu'] + v(0, .08, 0) * G['s']; J['chest'] = v(0, 1.12, 0) * G['s']; J['neck'] = v(0, 1.22, -.01) * G['s']; J['head'] = G['head_c']; J['head_top'] = G['head_c'] + v(0, G['head_r'][1], 0)
        for sd, nm in ((1, 'L'), (-1, 'R')):
            sh, el, wr, _ = G['arms'][sd]; J['clav.' + nm] = v(sd * .06, 1.2, .01) * G['s']; J['upperarm.' + nm] = sh; J['forearm.' + nm] = el; J['hand.' + nm] = wr
            J['fingers.' + nm] = wr + nrm(wr - el) * .09 * G['s']
            hp, kn, an = G['legs'][sd]; J['thigh.' + nm] = hp; J['shin.' + nm] = kn; J['foot.' + nm] = an; J['toe.' + nm] = an + v(sd * .01, -.06, .1) * G['s']
        meta['joints'] = {k: [round(float(x), 4) for x in val] for k, val in J.items()}
        for e in inst: bpy.data.objects.remove(e)
    # 2) dáng nhân vật 3/4 + Bơ
    show(ca_, False); show(cp_, True)
    bo_root.location = (.55 * hh / 1.6 + .25, .25, 0); bo_root.rotation_euler = (0, 0, .35)
    cd.type = 'PERSP'; cd.lens = 70
    scn.render.resolution_x = 1000; scn.render.resolution_y = 1100
    tgt = Vector((.12, 0, hh * .5)); cam.location = tgt + Vector((.42, -1, .14)).normalized() * 2.4 * max(hh, 1.25)
    cam.rotation_euler = (tgt - cam.location).to_track_quat('-Z', 'Y').to_euler()
    scn.render.filepath = f'{out}/{cid}{SUF[0]}_dang.png'; bpy.ops.render.render(write_still=True)
    # 3) cận mặt
    show(bo_coll, False)
    Gh = Gp; FRp, upw, hw = frames(Gh); hcw = B(hw(Gh['head_c']))
    cam.location = hcw + Vector((.32, -.95, .08)) * Gh['hh'] / .29; cd.lens = 85
    cam.rotation_euler = (hcw + Vector((0, 0, -.01)) - cam.location).to_track_quat('-Z', 'Y').to_euler()
    scn.render.resolution_x = 800; scn.render.resolution_y = 800
    scn.render.filepath = f'{out}/{cid}{SUF[0]}_mat.png'; bpy.ops.render.render(write_still=True)
    with open(f'{out}/{cid}{SUF[0]}.json', 'w') as f: json.dump(meta, f, ensure_ascii=False)
    if glb:
      fl.hide_set(True)
      if not POSE_ONLY[0]:
        show(bo_coll, False); show(cp_, False); show(ca_, True); fl.hide_set(True)
        for o in scn.objects: o.select_set(False)
        for o in ca_.objects:
            o.select_set(True)
            if o.type == 'MESH' and o.name.endswith('_than'):
                md = o.modifiers.new('Dec', 'DECIMATE'); md.ratio = 3500 / max(1, len(o.data.polygons))
        bpy.ops.export_scene.gltf(filepath=f'{out}/{cid}.glb', use_selection=True, export_apply=True, export_vertex_color='ACTIVE')
      show(bo_coll, False); show(ca_, False); show(cp_, True)
      if True:
        for o in scn.objects: o.select_set(False)
        for o in cp_.objects:
            o.select_set(True)
            if o.type == 'MESH' and (o.name.endswith('_than') or o.name.endswith('_do')):
                md = o.modifiers.new('Dec', 'DECIMATE'); md.ratio = (6000 if o.name.endswith('_than') else 1500) / max(1, len(o.data.polygons))
        bpy.ops.export_scene.gltf(filepath=f'{out}/{cid}{SUF[0]}_dang.glb', use_selection=True, export_apply=True, export_vertex_color='ACTIVE')
    print('done', cid)

if __name__ == '__main__':
    if '--giao' in sys.argv: CHARS[sys.argv[1]]['pose'] = GIAO[sys.argv[1]]
    run(sys.argv[1], sys.argv[2], '--glb' in sys.argv)
