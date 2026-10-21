"""Bơ phong cách dễ thương: 3 phương án (chibi, bong, tron) dựng bằng SDF rồi render Eevee.
Dùng: python3 cute.py <style> <outdir> [views] [--glb]
Toạ độ SDF theo three.js (mét, Y lên, mèo nhìn +Z)."""
import sys, math, numpy as np
from skimage import measure
from sdflib import v, ellipsoid, sphere, roundcone, smin, smax, chain, catmull, hexc, sstep, noise

STYLE = sys.argv[1]; OUT = sys.argv[2]
VIEWS = [x for x in (sys.argv[3].split(',') if len(sys.argv) > 3 else ['q34', 'side']) if x]
H = 0.0035

# ---------------- tham số từng phong cách ----------------
STYLES = {
 'chibi': dict(
   head=((0, .34, .04), (.2, .17, .175)), cheek=((.1, .29, .1), (.1, .075, .09)),
   body=((0, .15, -.04), (.115, .105, .14)), chest=((0, .2, .04), (.09, .08, .08)),
   fl=dict(x=.062, z=.055, top=.14, r=(.042, .04)), hl=dict(x=.07, z=-.12, top=.13, r=(.045, .042)),
   haunch=((.07, .11, -.11), (.06, .07, .075)), paw=(.046, .032, .052),
   tail=([(0, .15, -.17), (0, .17, -.25), (0, .27, -.28), (0, .34, -.23)], (.042, .034)),
   ear=dict(base=(.105, .46, .03), up=(.5, .86, 0), L=.08, r=(.066, .024), th=1.5),
   pads=((.02, .29, .205), .028), nose=((0, .31, .225), (.013, .009, .008)),
   eye=dict(kind='dot', c=(.085, .345, .19), r=(.034, .046, .02)),
   col=dict(fur='#F7A65A', fur2='#E9863A', belly='#FFF3E0', blush='#FF9C9C', earin='#FFB8B0', nose='#F07F86', line='#5A3426'),
   stripes='few', neck=((0, .2, .04), (0, .9, .44), .02, .16), scarf='#E5574B'),
 'bong': dict(
   head=((0, .33, .05), (.18, .155, .16)), cheek=((.085, .285, .1), (.09, .07, .08)),
   body=((0, .155, -.04), (.13, .12, .155)), chest=((0, .21, .05), (.095, .085, .08)),
   fl=dict(x=.07, z=.065, top=.12, r=(.052, .05)), hl=dict(x=.078, z=-.12, top=.12, r=(.054, .052)),
   haunch=((.075, .12, -.11), (.06, .075, .08)), paw=(.052, .036, .056),
   tail=([(0, .16, -.18), (0, .17, -.26), (0, .23, -.3)], (.046, .042)),
   ear=dict(base=(.098, .44, .04), up=(.45, .89, 0), L=.07, r=(.06, .032), th=1.3),
   pads=((.018, .285, .2), .026), nose=((0, .305, .215), (.013, .009, .008)),
   eye=dict(kind='button', c=(.07, .335, .19), r=(.027, .027, .014)),
   col=dict(fur='#EEA765', fur2='#D98B4A', belly='#FBEBD3', blush='#F5A7A0', earin='#F7B9AE', nose='#C9656B', line='#5A3426'),
   stripes='seam', neck=((0, .21, .05), (0, .9, .44), .02, .16), scarf='#D9574D'),
 'tron': dict(
   head=((0, .38, .11), (.165, .145, .15)), cheek=((.08, .33, .17), (.085, .065, .07)),
   body=((0, .2, -.03), (.12, .115, .17)), chest=((0, .25, .08), (.095, .09, .08)),
   fl=dict(x=.066, z=.075, top=.2, r=(.042, .037)), hl=dict(x=.075, z=-.13, top=.16, r=(.045, .04)),
   haunch=((.07, .18, -.12), (.065, .09, .085)), paw=(.043, .03, .05),
   tail=([(0, .22, -.19), (0, .24, -.29), (0, .36, -.33), (0, .47, -.29), (0, .5, -.22)], (.036, .03)),
   ear=dict(base=(.09, .5, .1), up=(.42, .9, -.05), L=.1, r=(.06, .018), th=1.8),
   pads=((.02, .345, .255), .03), nose=((0, .365, .278), (.014, .01, .009)),
   eye=dict(kind='iris', c=(.068, .388, .24), r=(.04, .048, .024)),
   col=dict(fur='#F29A48', fur2='#D9742B', belly='#FFF0DC', blush='#FF9C94', earin='#FFB2A8', nose='#E8737C', line='#4A2A1E'),
   stripes='soft', neck=((0, .27, .09), (0, .93, .36), .022, .16), scarf='#DE4E43'),
'chung': dict(
   head=((0, .43, .17), (.12, .105, .11)), cheek=((.06, .4, .2), (.065, .05, .055)),
   body=((0, .24, -.03), (.108, .112, .19)), chest=((0, .29, .11), (.092, .1, .09)),
   fl=dict(x=.056, z=.1, top=.27, r=(.036, .029), off=(.035, -.01)), hl=dict(x=.064, z=-.15, top=.22, r=(.04, .031), off=(-.01, .03)),
   haunch=((.064, .24, -.14), (.058, .1, .09)), paw=(.034, .024, .044),
   tail=([(0, .27, -.2), (0, .25, -.31), (0, .33, -.39), (.02, .47, -.41), (.04, .55, -.35), (.03, .57, -.29)], (.03, .023)),
   ear=dict(base=(.072, .5, .16), up=(.4, .92, -.06), L=.095, r=(.05, .012), th=2.2),
   pads=((.017, .388, .262), .024), nose=((0, .402, .28), (.011, .008, .007)),
   eye=dict(kind='iris', c=(.05, .44, .263), r=(.031, .025, .017), lid=.18, pupil='slit', iris=('#D8B03E', '#7A5A1A')),
   pose=dict(yaw=.28, pitch=-.08, roll=.06, pivot=(0, .34, .12)), blush=.25,
   col=dict(fur='#E8913A', fur2='#B9601C', belly='#FBE6C8', blush='#F09080', earin='#E59A8C', nose='#C45A5E', line='#3A2418'),
   stripes='soft', neck=((0, .335, .13), (0, .9, .44), .02, .14), scarf='#C8412F'),
 'chung2': None,
 'thuc': dict(
   head=((0, .42, .19), (.105, .093, .1)), cheek=((.052, .39, .215), (.058, .045, .05)),
   body=((0, .24, -.03), (.1, .11, .2)), chest=((0, .29, .12), (.085, .095, .085)),
   fl=dict(x=.052, z=.11, top=.27, r=(.032, .025), off=(.04, -.015)), hl=dict(x=.06, z=-.16, top=.22, r=(.037, .027), off=(-.015, .03)),
   haunch=((.06, .24, -.15), (.055, .1, .09)), paw=(.03, .021, .04),
   tail=([(0, .27, -.21), (0, .24, -.32), (0, .3, -.41), (.02, .43, -.44), (.045, .52, -.4), (.04, .56, -.34)], (.026, .019)),
   ear=dict(base=(.062, .48, .18), up=(.42, .9, -.08), L=.1, r=(.046, .009), th=2.4),
   pads=((.015, .382, .27), .021), nose=((0, .395, .287), (.01, .007, .006)),
   eye=dict(kind='iris', c=(.043, .43, .27), r=(.024, .021, .014), lid=.15, pupil='slit', iris=('#C9C24A', '#6E7A22')),
   pose=dict(yaw=.32, pitch=-.06, roll=.05, pivot=(0, .34, .13)), blush=0,
   col=dict(fur='#E08A3A', fur2='#A9561A', belly='#F6E2C6', blush='#F09080', earin='#D98C80', nose='#B65558', line='#2E1C12'),
   stripes='dense', neck=((0, .335, .14), (0, .9, .44), .018, .13), scarf='#B8382A'),
}
if STYLES['chung2'] is None:
    import copy
    c2 = copy.deepcopy(STYLES['chung'])
    c2['eye'] = dict(kind='iris', c=(.05, .442, .263), r=(.033, .027, .018), lid=.08, lidtilt=-.1, smile=.16, roll=.16,
                     pupil='slit', pupilw=.5, iris=('#F7D35E', '#CC8E2C'), ring='#8A5520', smilemouth=True)
    c2['pose'] = dict(yaw=.28, pitch=.04, roll=.05, pivot=(0, .34, .12))
    c2['blush'] = .3
    # đuôi ngắn như mèo nhà thật (Sang 21/10): ~0,30 m dọc đường cong, rủ xuống rồi cong nhẹ lên
    c2['tail'] = ([(0, .27, -.2), (0, .25, -.285), (0, .29, -.35), (.012, .36, -.385), (.02, .42, -.375)], (.03, .022))
    STYLES['chung2'] = c2
S = STYLES[STYLE]

xs = np.arange(-.24, .24, H, dtype=np.float32); ys = np.arange(-.01, .66, H, dtype=np.float32); zs = np.arange(-.5, .36, H, dtype=np.float32)
X, Y, Z = np.meshgrid(xs, ys, zs, indexing='ij'); P = np.stack([X, Y, Z], -1)

PO = S.get('pose')
def _rot(yaw, pitch, roll):
    cy, sy_, cp, sp, cr, sr = math.cos(yaw), math.sin(yaw), math.cos(pitch), math.sin(pitch), math.cos(roll), math.sin(roll)
    Ry = np.array([[cy, 0, sy_], [0, 1, 0], [-sy_, 0, cy]], np.float32)
    Rx = np.array([[1, 0, 0], [0, cp, -sp], [0, sp, cp]], np.float32)
    Rz = np.array([[cr, -sr, 0], [sr, cr, 0], [0, 0, 1]], np.float32)
    return Ry @ Rx @ Rz
HR = _rot(PO['yaw'], PO['pitch'], PO['roll']) if PO else np.eye(3, dtype=np.float32)
HPIV = v(*PO['pivot']) if PO else v(0, 0, 0)
def head_local(p):  # điểm thế giới -> toạ độ đầu chưa xoay
    return (p - HPIV) @ HR + HPIV
def head_world(p):
    return (np.asarray(p, np.float32) - HPIV) @ HR.T + HPIV

def ear_frame(side):
    e = S['ear']; base = v(side * e['base'][0], *e['base'][1:])
    up = v(side * e['up'][0], *e['up'][1:]); up /= np.linalg.norm(up)
    fwd = v(0, .1, 1); fwd -= up * (fwd @ up); fwd /= np.linalg.norm(fwd); rt = np.cross(up, fwd)
    return base, up, fwd, rt

def ear_sdf(p, side):
    e = S['ear']; base, up, fwd, rt = ear_frame(side); q = p - base
    lx, ly, lz = q @ rt, q @ up, q @ fwd; th = e['th']
    out = roundcone(np.stack([lx, ly, lz * th], -1), v(0, -.02, 0), v(0, e['L'], 0), e['r'][0], e['r'][1]) / th * 1.3
    inn = roundcone(np.stack([lx * 1.2, ly - .01, (lz - .018) * th], -1), v(0, 0, 0), v(0, e['L'] * .85, 0), e['r'][0] * .75, e['r'][1] * .6) / th * 1.3
    return smax(out, -inn, .008), (lx, ly, lz)

def body_sdf(p):
    hc, hr = S['head']; d = ellipsoid(p, v(*S['body'][0]), v(*S['body'][1]))
    d = smin(d, ellipsoid(p, v(*S['chest'][0]), v(*S['chest'][1])), .04)
    for s in (-1, 1):
        hc_, hr_ = S['haunch']; d = smin(d, ellipsoid(p, v(s * hc_[0], *hc_[1:]), v(*hr_)), .03)
        for L in (S['fl'], S['hl']):
            x = s * L['x']; dz = L.get('off', (0, 0))[0 if s < 0 else 1]
            leg = roundcone(p, v(x, L['top'], L['z']), v(x, .04, L['z'] + .005 + dz), *L['r'])
            pw = S['paw']; paw = ellipsoid(p, v(x, pw[1] * .9, L['z'] + .012 + dz), v(*pw))
            d = smin(d, smin(leg, paw, .02), .03)
    tp = catmull(S['tail'][0], 6); rr = np.linspace(*S['tail'][1], len(tp)).astype(np.float32)
    d = smin(d, chain(p, list(tp), list(rr), .006), .03)
    p = head_local(p)
    hd = ellipsoid(p, v(*hc), v(*hr))
    cc, cr = S['cheek']
    for s in (-1, 1): hd = smin(hd, ellipsoid(p, v(s * cc[0], *cc[1:]), v(*cr)), .04)
    pc, prr = S['pads']
    for s in (-1, 1): hd = smin(hd, sphere(p, v(s * pc[0], *pc[1:]), prr), .015)
    hd = smin(hd, ellipsoid(p, v(*S['nose'][0]), v(*S['nose'][1])), .008)
    ec = S['eye']['c']
    for s in (-1, 1): hd = smax(hd, -ellipsoid(p, v(s * ec[0], ec[1], ec[2] + .004), v(*S['eye']['r']) * v(1.05, 1.05, 1.6)), .01)
    lid = S['eye'].get('lid')
    if lid:
        er = v(*S['eye']['r'])
        for s in (-1, 1):
            c_ = v(s * ec[0], *ec[1:]); u = v(s * S['eye'].get('lidtilt', .12), 1, .12); u /= np.linalg.norm(u)
            lv = smax(ellipsoid(p, c_, er * v(1.12, 1.15, 1.25)), -((p - c_) @ u - er[1] * (1 - 2 * lid)), .003)
            hd = smin(hd, lv, .006)
            sm = S['eye'].get('smile')
            if sm:  # mí dưới hơi đẩy lên: mắt cười
                d_ = v(s * .15, -1, .15); d_ /= np.linalg.norm(d_)
                lw = smax(ellipsoid(p, c_ + v(0, -er[1] * .25, 0), er * v(1.15, 1.0, 1.2)), -((p - c_) @ d_ - er[1] * (1 - 2 * sm)), .003)
                hd = smin(hd, lw, .008)
    for s in (-1, 1): hd = smin(hd, ear_sdf(p, s)[0], .018)
    return smin(d, hd, .05)

def scarf_sdf(p, body):
    c, n, hw, rad = S['neck']; c = v(*c); n = v(*n); n /= np.linalg.norm(n)
    ang = np.arctan2(p[..., 0], p[..., 2] - c[2])
    band = np.abs((p - c) @ n + .003 * np.sin(ang * 8)) - hw
    shell = np.abs(body - .018) - .02
    d = smax(smax(shell, band, .012), -body, .004); d = smax(d, sphere(p, c, rad), .01)
    # nút thắt trước-trái + hai đuôi khăn tròn
    dr = v(-.55, -.1, .83); dr /= np.linalg.norm(dr); t = 0.
    while body_sdf(np.array([c + dr * t]))[0] < 0: t += .003
    k = c + dr * (t + .02)
    d = smin(d, ellipsoid(p, k, v(.028, .024, .022)), .01)
    d = smin(d, chain(p, [k, k + v(-.012, -.04, .012), k + v(-.02, -.075, .006)], [.017, .016, .02], .004), .008)
    d = smin(d, chain(p, [k, k + v(.016, -.035, .01), k + v(.024, -.065, .0)], [.016, .015, .019], .004), .008)
    return d

def mesh(field):
    V, F, N, _ = measure.marching_cubes(field, 0.0, spacing=(H, H, H), gradient_direction='descent')
    return (V + np.array([xs[0], ys[0], zs[0]], np.float32)).astype(np.float32), F.astype(np.int32), (-N).astype(np.float32)

def seg(V, a, b):
    pa = V - a; ba = b - a; h = np.clip((pa @ ba) / (ba @ ba), 0, 1)
    return np.linalg.norm(pa - h[:, None] * ba, axis=1)

def colors(V, N):
    c = S['col']; FUR, FUR2, BELLY, BLUSH, EARIN, NOSE, LINE = (hexc(c[k]) for k in ('fur', 'fur2', 'belly', 'blush', 'earin', 'nose', 'line'))
    Vw = V; V = head_local(V) if PO else V
    x, y, z = V[:, 0], V[:, 1], V[:, 2]
    xw, yw, zw = Vw[:, 0], Vw[:, 1], Vw[:, 2]
    col = np.tile(FUR, (len(V), 1))
    mix = lambda col, m, C: col * (1 - m[:, None]) + C * m[:, None]
    hc, hr = S['head']; top = hc[1] + hr[1]
    st = np.zeros(len(V), np.float32)
    if S['stripes'] in ('few', 'soft', 'dense'):
        # 3 vạch trán
        fore = sstep(top - .07, top - .045, y) * sstep(hc[2] + .04, hc[2] + .08, z) * sstep(.05, .035, np.abs(x))
        st = np.maximum(st, sstep(.5, .85, np.cos(x * 190)) * fore)
        # vạch lưng
        bz = S['body'][0]
        bl = S['body'][1][2]; btop = S['body'][0][1] + S['body'][1][1]
        back = sstep(.3, .6, N[:, 1]) * sstep(bz[2] + bl * .7, bz[2] + bl * .45, zw) * sstep(bz[2] - bl * .9, bz[2] - bl * .65, zw) * sstep(btop - .08, btop - .03, yw)
        st = np.maximum(st, sstep(.4, .8, np.sin(zw * (90 if S['stripes'] == 'few' else 110))) * back)
        # vòng đuôi
        tz = S['tail'][0][1][2]
        tail = sstep(tz + .04, tz, zw) * sstep(.0, .02, yw)
        st = np.maximum(st, sstep(.55, .85, np.sin((yw - zw * .5) * (55 if S['stripes'] == 'few' else 80))) * tail)
        if S['stripes'] in ('soft', 'dense'):
            fq = 110 if S['stripes'] == 'soft' else 150
            nz_ = noise(Vw) * (1.2 if S['stripes'] == 'dense' else 0)
            side = sstep(.4, .7, np.abs(N[:, 0])) * sstep(bz[2] + bl * .6, bz[2] + bl * .3, zw) * sstep(bz[2] - bl * .85, bz[2] - bl * .55, zw) * sstep(.12, .17, yw)
            st = np.maximum(st, sstep(.5, .85, np.sin(zw * fq + 1 + nz_)) * side * .9)
            if PO:
                legs_ = sstep(.2, .14, yw) * sstep(.05, .07, yw) * sstep(.3, .6, np.abs(N[:, 0]))
                st = np.maximum(st, sstep(.55, .85, np.sin(yw * 130 + nz_)) * legs_ * .8)
                ck = sstep(hr[0] * .55, hr[0] * .75, np.abs(x)) * sstep(hc[1] - .04, hc[1] - .02, y) * sstep(hc[1] + .03, hc[1] + .01, y) * sstep(hc[2], hc[2] + .03, z)
                st = np.maximum(st, sstep(.55, .85, np.sin(y * 260 + 1.2)) * ck)
    col = mix(col, st, FUR2)
    # bụng, ngực, mõm, bàn chân, chóp đuôi: kem
    pc, prr = S['pads']
    pads = np.minimum(np.linalg.norm(V - v(pc[0], *pc[1:]), axis=1), np.linalg.norm(V - v(-pc[0], *pc[1:]), axis=1))
    muz = sstep(prr + .022, prr + .008, pads)
    ch = S['chest'][0]
    chest = sstep(ch[2] + .0, ch[2] + .06, z) * sstep(hc[1] - .04, hc[1] - .1, y) * sstep(.075, .04, np.abs(x))
    belly = sstep(.1, -.5, N[:, 1]) * sstep(.04, .07, yw) * sstep(S['body'][0][1] + .05, S['body'][0][1], yw)
    paws = sstep(.05, .035, yw)
    tip = S['tail'][0][-1]; tipm = sstep(.055, .03, np.linalg.norm(Vw - v(*tip), axis=1))
    col = mix(col, np.clip(np.maximum.reduce([muz, chest, belly, paws, tipm]), 0, 1), BELLY)
    # má hồng
    ec = S['eye']['c']; er = S['eye']['r']
    for s in (-1, 1):
        b = v(s * (ec[0] + er[0] * .9), ec[1] - er[1] * 1.25, ec[2] - .012)
        col = mix(col, sstep(.032, .012, np.linalg.norm((V - b) * v(1, 1.4, 1), axis=1)) * S.get('blush', .85), BLUSH)
    # trong tai
    for s in (-1, 1):
        ed, (lx, ly, lz) = ear_sdf(V, s)
        e = (ed < .008) * sstep(-.004, .003, lz) * sstep(.0, .015, ly) * sstep(0, .01, (S['ear']['r'][0] * .7 - ly * .45) - np.abs(lx))
        col = mix(col, e, EARIN)
    # mũi + miệng chữ w
    nc, nr = S['nose']; nc = v(*nc)
    col = mix(col, sstep(nr[0] * 1.15, nr[0] * .8, np.linalg.norm((V - nc) * v(1, 1.3, 1), axis=1)), NOSE)
    m0 = nc + v(0, -.012, 0); zl = nc[2] - .003
    up_ = .004 if S['eye'].get('smilemouth') else -.002
    pts = [v(-.026, m0[1] + up_, zl - .006), v(-.012, m0[1] - .012, zl), m0, v(.012, m0[1] - .012, zl), v(.026, m0[1] + up_, zl - .006)]
    dl = np.minimum.reduce([seg(V, nc + v(0, -.006, 0), m0)] + [seg(V, pts[i], pts[i + 1]) for i in range(4)])
    col = mix(col, sstep(.0034, .002, dl), LINE)
    if S['stripes'] == 'seam':  # đường chỉ may giữa đầu và hai bên thân
        seam = sstep(.0025, .001, np.abs(x)) * sstep(hc[1] + .02, hc[1] + .06, y) * (z < hc[2] + .1)
        dash = sstep(-.2, .3, np.sin((y - z) * 420))
        col = mix(col, seam * dash * .8, hexc('#B06A35'))
        # 2 vạch thêu trên trán
        fore = sstep(top - .06, top - .04, y) * sstep(hc[2] + .05, hc[2] + .09, z)
        st2 = sstep(.003, .0015, np.minimum(np.abs(np.abs(x) - .022), 1)) * fore
        col = mix(col, st2, hexc(c['fur2']))
    return col

body = body_sdf(P); V, F, N = mesh(body); C = colors(V, N)
SV, SF, _ = mesh(scarf_sdf(P, body))
print(STYLE, 'body tris', len(F), 'scarf tris', len(SF))

# ---------------- Blender ----------------
import bpy
from mathutils import Vector, Euler, Matrix
bpy.ops.wm.read_factory_settings(use_empty=True); sc = bpy.context.scene

def B(p): return Vector((p[0], -p[2], p[1]))
def lin(h, a=1.0):
    c = hexc(h); c = np.where(c <= .04045, c / 12.92, ((c + .055) / 1.055) ** 2.4); return (*c, a)

def make_mesh(name, V, F, C=None):
    me = bpy.data.meshes.new(name); Vb = np.stack([V[:, 0], -V[:, 2], V[:, 1]], 1)
    me.vertices.add(len(Vb)); me.vertices.foreach_set('co', Vb.ravel())
    me.loops.add(F.size); me.loops.foreach_set('vertex_index', F.ravel())
    me.polygons.add(len(F)); me.polygons.foreach_set('loop_start', np.arange(0, F.size, 3)); me.update(); me.validate()
    if C is not None:
        ca = me.color_attributes.new('Col', 'FLOAT_COLOR', 'POINT')
        L = np.where(C <= .04045, C / 12.92, ((C + .055) / 1.055) ** 2.4)
        ca.data.foreach_set('color', np.concatenate([L, np.ones((len(C), 1))], 1).astype(np.float32).ravel())
    me.polygons.foreach_set('use_smooth', [True] * len(me.polygons))
    ob = bpy.data.objects.new(name, me); sc.collection.objects.link(ob)
    md = ob.modifiers.new('Smooth', 'SMOOTH'); md.factor = .5; md.iterations = 6
    return ob

def material(name, color=None, attr=False, kind='pbr', rough=.6):
    m = bpy.data.materials.new(name); nt = m.node_tree if m.node_tree else None
    if nt is None: m.use_nodes = True; nt = m.node_tree
    N_ = nt.nodes; Lk = nt.links; bs = N_['Principled BSDF']; out = N_['Material Output']
    if attr:
        a = N_.new('ShaderNodeVertexColor'); a.layer_name = 'Col'; src = a.outputs['Color']
    else:
        rgb = N_.new('ShaderNodeRGB'); rgb.outputs[0].default_value = lin(color); src = rgb.outputs[0]
    Lk.new(src, bs.inputs['Base Color']); bs.inputs['Roughness'].default_value = rough
    if kind == 'toon':
        # đổ bóng 2 bậc + viền sáng mềm: kiểu Animal Crossing / Ni no Kuni
        df = N_.new('ShaderNodeBsdfDiffuse'); s2r = N_.new('ShaderNodeShaderToRGB'); Lk.new(df.outputs[0], s2r.inputs[0])
        ramp = N_.new('ShaderNodeValToRGB'); ramp.color_ramp.interpolation = 'EASE'
        e0, e1 = ramp.color_ramp.elements; e0.position = .3; e0.color = (.66, .6, .7, 1); e1.position = .38; e1.color = (1, 1, 1, 1)
        Lk.new(s2r.outputs['Color'], ramp.inputs['Fac'])
        mul = N_.new('ShaderNodeMix'); mul.data_type = 'RGBA'; mul.blend_type = 'MULTIPLY'; mul.inputs['Factor'].default_value = 1
        Lk.new(src, mul.inputs[6]); Lk.new(ramp.outputs['Color'], mul.inputs[7])
        lw = N_.new('ShaderNodeLayerWeight'); lw.inputs['Blend'].default_value = .25
        rim = N_.new('ShaderNodeMath'); rim.operation = 'GREATER_THAN'; rim.inputs[1].default_value = .72
        Lk.new(lw.outputs['Facing'], rim.inputs[0])
        add = N_.new('ShaderNodeMix'); add.data_type = 'RGBA'; add.blend_type = 'SCREEN'
        rimc = N_.new('ShaderNodeMath'); rimc.operation = 'MULTIPLY'; rimc.inputs[1].default_value = .35; Lk.new(rim.outputs[0], rimc.inputs[0])
        Lk.new(rimc.outputs[0], add.inputs['Factor']); Lk.new(mul.outputs[2], add.inputs[6]); add.inputs[7].default_value = (1, .97, .9, 1)
        em = N_.new('ShaderNodeEmission'); Lk.new(add.outputs[2], em.inputs['Color'])
        Lk.new(em.outputs[0], out.inputs['Surface'])
    elif kind == 'plush':
        bs.inputs['Roughness'].default_value = 1.0; bs.inputs['Sheen Weight'].default_value = 1.0
        bs.inputs['Sheen Roughness'].default_value = .35; bs.inputs['Sheen Tint'].default_value = (1, .95, .9, 1)
        tc = N_.new('ShaderNodeTexCoord'); nz = N_.new('ShaderNodeTexNoise'); nz.inputs['Scale'].default_value = 1400; nz.inputs['Detail'].default_value = 4
        Lk.new(tc.outputs['Object'], nz.inputs['Vector'])
        bp = N_.new('ShaderNodeBump'); bp.inputs['Strength'].default_value = .35; bp.inputs['Distance'].default_value = .002
        Lk.new(nz.outputs['Fac'], bp.inputs['Height']); Lk.new(bp.outputs['Normal'], bs.inputs['Normal'])
    else:
        bs.inputs['Sheen Weight'].default_value = .45; bs.inputs['Coat Weight'].default_value = 0; bs.inputs['Specular IOR Level'].default_value = .3
    return m

kind = {'chibi': 'toon', 'bong': 'plush'}.get(STYLE, 'pbr')
body_ob = make_mesh('Bo_Than', V, F, C); body_ob.data.materials.append(material('Long', attr=True, kind=kind, rough=.78 if kind == 'pbr' else .8))
scarf_ob = make_mesh('Bo_Khan', SV, SF); scarf_ob.data.materials.append(material('Khan', S['scarf'], kind=kind if kind != 'pbr' else 'plush', rough=.9))

def sph(name, loc, r, scale=(1, 1, 1), mat=None, rot=None, seg=40):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=seg, ring_count=seg // 2, radius=r, location=loc)
    o = bpy.context.active_object; o.name = name; o.scale = scale
    if rot is not None: o.rotation_euler = rot
    if mat: o.data.materials.append(mat)
    bpy.ops.object.shade_smooth(); return o

def unlit(name, color, strength=1.0):
    m = bpy.data.materials.new(name)
    if m.node_tree is None: m.use_nodes = True
    nt = m.node_tree; em = nt.nodes.new('ShaderNodeEmission'); em.inputs['Color'].default_value = lin(color); em.inputs['Strength'].default_value = strength
    nt.links.new(em.outputs[0], nt.nodes['Material Output'].inputs['Surface']); return m

# mắt: hướng theo pháp tuyến mặt đầu tại chỗ đặt mắt
E = S['eye']; hc, hr = S['head']
for s in (-1, 1):
    c = v(s * E['c'][0], *E['c'][1:]); nrm = (c - v(*hc)) / v(*hr) ** 2; nrm /= np.linalg.norm(nrm)
    upv = HR @ v(0, 1, 0); c = head_world(c); nrm = HR @ nrm
    fwd = B(nrm).normalized(); upB = B(upv)
    xr = upB.cross(fwd).normalized(); zu = fwd.cross(xr).normalized()
    q = Matrix((xr, -fwd, zu)).transposed().to_quaternion()
    if E.get('roll'):
        from mathutils import Quaternion
        q = Quaternion(fwd, s * E['roll']) @ q
    rot = q.to_euler()
    loc = B(c); up = q @ Vector((0, 0, 1)); rt = q @ Vector((1, 0, 0))
    if E['kind'] in ('dot', 'button'):
        gl = bpy.data.materials.new('Mat_den')
        if gl.node_tree is None: gl.use_nodes = True
        b = gl.node_tree.nodes['Principled BSDF']; b.inputs['Base Color'].default_value = lin('#1E1716'); b.inputs['Roughness'].default_value = .08
        b.inputs['Coat Weight'].default_value = 1.0
        sph('Mat', loc, 1, (E['r'][0], E['r'][2], E['r'][1]), gl, rot)
        hi = unlit('Sang', '#FFFFFF', 1.0)
        sph('Sang1', loc + fwd * E['r'][2] * .9 + up * E['r'][1] * .38 + rt * (-s) * E['r'][0] * .25 * 0 + rt * E['r'][0] * .3, E['r'][0] * .32, mat=hi)
        sph('Sang2', loc + fwd * E['r'][2] * .9 - up * E['r'][1] * .35 - rt * E['r'][0] * .25, E['r'][0] * .14, mat=hi)
        if E['kind'] == 'button':
            bpy.ops.mesh.primitive_torus_add(major_radius=E['r'][0] * .95, minor_radius=.004, location=loc + fwd * .002)
            t = bpy.context.active_object; t.rotation_euler = (q @ Euler((math.pi / 2, 0, 0)).to_quaternion()).to_euler(); t.data.materials.append(gl)
    else:
        o = sph('Mat', loc, 1, (E['r'][0], E['r'][2], E['r'][1]), None, rot, 128)
        me = o.data; ca = me.color_attributes.new('Col', 'FLOAT_COLOR', 'POINT'); cols = []
        for vt in me.vertices:
            p = vt.co.normalized(); f = -p.y; r = math.hypot(p.x, p.z)
            if f < .15: cc = lin('#FFFFFF')
            elif (E.get('pupil') == 'slit' and abs(p.x) < E.get('pupilw', .16) * max(0, 1 - (p.z / .78) ** 2) and r < .8) or (E.get('pupil') != 'slit' and r < .5): cc = lin('#1A0F0A')
            elif r < .82:
                ic = E.get('iris', ('#E8B54A', '#A8641E'))
                t_ = max(0, (r - .3) / .52); a, bb = lin(ic[0]), lin(ic[1]); cc = tuple(a[i] * (1 - t_) + bb[i] * t_ for i in range(3)) + (1,)
            else: cc = lin(E.get('ring', '#5A3418'))
            cols.extend(cc)
        ca.data.foreach_set('color', cols)
        m = material('Mat_iris', attr=True, rough=.05); m.node_tree.nodes['Principled BSDF'].inputs['Coat Weight'].default_value = 1
        me.materials.append(m)
        hi = unlit('Sang', '#FFFFFF', 1.0)
        sph('Sang1', loc + fwd * E['r'][2] * .95 + up * E['r'][1] * .35 + rt * E['r'][0] * .3, E['r'][0] * .17, mat=hi)
        sph('Sang2', loc + fwd * E['r'][2] * .95 - up * E['r'][1] * .3 - rt * E['r'][0] * .25, E['r'][0] * .12, mat=hi)

# sàn, nền pastel, đèn
bpy.ops.mesh.primitive_plane_add(size=40); fl = bpy.context.active_object
fm = bpy.data.materials.new('San')
if fm.node_tree is None: fm.use_nodes = True
fb = fm.node_tree.nodes['Principled BSDF']; fb.inputs['Base Color'].default_value = lin('#8CBFB4'); fb.inputs['Roughness'].default_value = 1
fl.data.materials.append(fm)
w = bpy.data.worlds.new('W'); sc.world = w
if w.node_tree is None: w.use_nodes = True
w.node_tree.nodes['Background'].inputs['Color'].default_value = lin('#9CCBC1'); w.node_tree.nodes['Background'].inputs['Strength'].default_value = .55

def light(name, kind, loc, target, power, size=1.0, color=(1, 1, 1)):
    l = bpy.data.lights.new(name, kind); l.energy = power; l.color = color
    if kind == 'AREA': l.size = size
    if kind == 'SUN': l.angle = .25
    o = bpy.data.objects.new(name, l); sc.collection.objects.link(o); o.location = loc
    o.rotation_euler = (Vector(target) - Vector(loc)).to_track_quat('-Z', 'Y').to_euler()
light('Key', 'SUN', (1.2, -1.2, 2.0), (0, 0, .25), 1.7, color=(1, .97, .92))
light('Fill', 'AREA', (-1.5, -.8, .9), (0, 0, .3), 60, 2.0, (.9, .95, 1))
light('Rim', 'AREA', (-.3, 1.6, 1.2), (0, 0, .3), 90, 1.0)

sc.render.engine = 'BLENDER_EEVEE'
try: sc.eevee.taa_render_samples = 32
except Exception: pass
try: sc.eevee.use_shadows = True
except Exception: pass
sc.render.resolution_x = 900; sc.render.resolution_y = 720
sc.view_settings.view_transform = 'Standard'
cd = bpy.data.cameras.new('Cam'); cam = bpy.data.objects.new('Cam', cd); sc.collection.objects.link(cam); sc.camera = cam
VD = {'q34': ((.95, -1.15, .6), None, 55), 'side': ((1.6, 0, .3), .98, 0), 'front': ((0, -1.6, .3), .98, 0), 'back': ((0, 1.6, .28), .85, 0), 'face': ((.12, -.75, .45), None, 120)}
for vn in VIEWS:
    loc, ortho, lens = VD[vn]; tgt = Vector((0, -.2, .43)) if vn == 'face' else Vector((0, .0, .27))
    cam.location = loc; cam.rotation_euler = (tgt - cam.location).to_track_quat('-Z', 'Y').to_euler()
    if ortho: cd.type = 'ORTHO'; cd.ortho_scale = ortho
    else: cd.type = 'PERSP'; cd.lens = lens
    sc.render.filepath = f'{OUT}/{STYLE}_{vn}.png'; bpy.ops.render.render(write_still=True); print('rendered', vn)

if '--glb' in sys.argv:
    fl.hide_set(True)
    for o in sc.objects: o.select_set(o.type == 'MESH' and o is not fl)
    for o in (body_ob, scarf_ob):
        md = o.modifiers.new('Dec', 'DECIMATE'); md.ratio = .4
    bpy.ops.export_scene.gltf(filepath=f'{OUT}/{STYLE}.glb', use_selection=True, export_apply=True, export_vertex_color='ACTIVE')
    bpy.ops.wm.save_as_mainfile(filepath=f'{OUT}/{STYLE}.blend'); print('glb done')
