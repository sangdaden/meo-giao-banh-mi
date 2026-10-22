"""Người dân Thứ Tư: áo mưa / dù cho 5 người đã duyệt (Chị Mây, Cô Hai, Bé Na, Chú Năm, Chú Tư).
Cùng bộ dựng nguoi.py + nguoi3.py (cùng mặt, cùng tỉ lệ). Áo mưa là khối SDF bọc ngoài thân nên dùng chung khung xương 19 khớp,
chỉ thêm 2 xương mũ trùm (hood) nếu luồng rig muốn cho mũ lay.
Dùng: python3 nguoi4.py <id> <outdir> [--glb]   id: may_mua, cohai_mua, bena_mua, chunam_mua, chutu_mua"""
import sys, os, math, copy, numpy as np
HERE = os.path.dirname(os.path.abspath(__file__)); sys.path.insert(0, HERE)
import nguoi as N
import nguoi3 as N3
from nguoi import v, ellipsoid, sphere, roundcone, smin, smax, chain, box, cyl, nrm

def mk(base, cid, name, role, **kw):
    c = copy.deepcopy(N.CHARS[base]); c.update(name=name, role=role, base=base); c.update(kw); N.CHARS[cid] = c; return c

mk('may', 'may_mua', 'Chị Mây (che dù)', 'Đơn 1 · kéo bàn ghế vào quán, che dù xanh', umbrella=('#3E8C5C', '#F1E6CF'))
mk('cohai', 'cohai_mua', 'Cô Hai (áo mưa cánh dơi)', 'Đơn 2 · nhận bánh ở quầy, áo mưa tím mũ trùm', coat='#8E5AA8', coat_kind='poncho', hood='up')
mk('bena', 'bena_mua', 'Bé Na (áo mưa vàng tai mèo)', 'Đơn 3 · thả giỏ có dù nhỏ từ ban công', coat='#F2C14E', coat_kind='poncho', hood='ears', basket=True)
mk('chunam', 'chunam_mua', 'Chú Năm (áo mưa bộ)', 'Đơn 4 · ngồi xe dưới bạt chờ khách', coat='#5E7A3A', coat_kind='jacket', hood='helmet')
mk('chutu', 'chutu_mua', 'Chú Tư (áo mưa trong)', 'Đơn 5 · tạnh mưa, cuộn bạt sạp báo', coat='#6FA8D6', coat_kind='poncho', hood='down', roll=True)

_pal = N.palette
def palette(c):
    P = _pal(c); P['aomua'] = c.get('coat', '#8E5AA8'); P['aomua2'] = '#F4EFE6'; P['taimeo'] = '#E8913A'; return P
N.palette = palette
N.GROUP.update(aomua='hard', aomua2='hard', taimeo='hard')

_b3 = N.build
def build(c, posed):
    parts, G, FR, headw = _b3(c, posed)
    ck = c.get('coat_kind')
    if not ck: return parts, G, FR, headw
    s = G['s']; bw = c['build']['bw']; bel = c['build']['belly']; hc, hr = G['head_c'], G['head_r']
    sc = lambda *a: v(*a) * s
    def add(name, fn, mat, frame, k=.03): parts.append(dict(name=name, fn=fn, mat=mat, frame=frame, k=k, sep=False))
    if ck == 'poncho':   # áo mưa cánh dơi: vai tròn, thân loe tới gối, tay áo rộng nối liền thân như cánh
        y0, y1 = 1.16 * s, .47 * s; r0, r1 = .16 * bw * s, .29 * max(bw, bel * .95) * s
        def body(p):
            y = p[..., 1]; t = np.clip((y0 - y) / (y0 - y1), 0, 1); r = r0 + (r1 - r0) * t ** .8
            rad = np.linalg.norm(np.stack([p[..., 0], (p[..., 2] - .01 * s) / .78], -1), axis=-1)
            d = (rad - r) * .9
            d = smax(d, smax(y - y0, y1 - y, .02 * s), .04 * s)
            return smin(d, ellipsoid(p, sc(0, 1.13, -.005), sc(.2 * bw, .1, .125)), .06 * s)
        add('aomua', body, 'aomua', 'up', k=.02 * s)
        for side, (sh, el, wr, n) in G['arms'].items():
            w2 = el + (wr - el) * .8
            add('aomua', (lambda sh, el, w2: lambda p: chain(p, [sh, el, w2], [.075 * s, .07 * s, .062 * s], .03))(sh, el, w2), 'aomua', 'up', k=.03 * s)
    if ck == 'jacket':   # áo mưa bộ: áo tới hông, tay áo ôm, quần mưa trùm ống
        def body(p):
            d = roundcone(p, sc(0, 1.12, 0), sc(0, .8, .01), .175 * bw * s, .19 * max(bel, bw) * s)
            return smax(d, smax(p[..., 1] - 1.2 * s, .72 * s - p[..., 1], .02 * s), .03 * s)
        add('aomua', body, 'aomua', 'up', k=.04 * s)
        add('aomua', lambda p: ellipsoid(p, sc(0, 1.15, -.005), sc(.19 * bw, .09, .12)), 'aomua', 'up', k=.05 * s)
        for side, (sh, el, wr, n) in G['arms'].items():
            w2 = el + (wr - el) * .85
            add('aomua', (lambda sh, el, w2: lambda p: chain(p, [sh, el, w2], [.058 * s, .05 * s, .046 * s], .02))(sh, el, w2), 'aomua', 'up', k=.03 * s)
        for side, (hp, kn, an) in G['legs'].items():
            a2 = kn + (an - kn) * .88
            add('aomua', (lambda hp, kn, a2: lambda p: chain(p, [hp, kn, a2], [.098 * s, .076 * s, .066 * s], .03))(hp, kn, a2), 'aomua', 'world', k=.012)
        add('aomua', lambda p: ellipsoid(p, sc(0, .82, 0), sc(.158 * c['build']['hip'], .1, .112 * max(1, bel * .9))), 'aomua', 'root', k=.04 * s)
    hood = c.get('hood')
    if hood in ('up', 'ears', 'helmet'):   # mũ trùm: vỏ ôm đầu, chừa mặt, viền trắng
        g = 1.12 if hood == 'helmet' else (1.36 if c['hair']['style'] == 'perm' else 1.26)
        def hd(p):
            e = ellipsoid(p, hc + v(0, hr[1] * .05, -hr[2] * .12), hr * v(g, g * .98, g * 1.04))
            return smax(e, (p[..., 2] - (hc[2] + hr[2] * (.42 if hood != 'helmet' else .3))) - .25 * np.maximum(0, hc[1] - hr[1] * .4 - p[..., 1]), .02 * s)
        add('aomua', hd, 'aomua', 'head', k=.015 * s)
        def rim(p):
            e = ellipsoid(p, hc + v(0, hr[1] * .05, -hr[2] * .12), hr * v(g, g * .98, g * 1.04) + .006 * s)
            pl = p[..., 2] - (hc[2] + hr[2] * (.42 if hood != 'helmet' else .3))
            return smax(np.abs(e) - .007 * s, np.abs(pl) - .012 * s, .004)
        add('aomua2', rim, 'aomua2', 'head', k=.004)
        add('aomua', lambda p: roundcone(p, hc + v(0, -hr[1] * .6, -hr[2] * .55), sc(0, 1.2, -.04), hr[0] * .6, .1 * s), 'aomua', 'up', k=.04 * s)
        if hood == 'ears':   # tai mèo trên mũ của Bé Na
            for sd in (-1, 1):
                add('taimeo', (lambda sd: lambda p: roundcone(p, hc + v(sd * hr[0] * .62, hr[1] * 1.0, -hr[2] * .1), hc + v(sd * hr[0] * .82, hr[1] * 1.45, -hr[2] * .05), hr[0] * .3, hr[0] * .05))(sd), 'aomua', 'head', k=.02 * s)
    if hood == 'down':   # mũ trùm bỏ xuống, xếp nếp sau gáy
        add('aomua', lambda p: ellipsoid(p, sc(0, 1.2, -.12), sc(.13, .08, .07)), 'aomua', 'up', k=.04 * s)
    return parts, G, FR, headw
N.build = build

def hook(scn, coll, G, headw, B):
    c = CUR['c']
    if not (c.get('umbrella') or c.get('basket') or c.get('roll')): return
    import bpy, pk, dscene, do4
    pk.sc = scn; pk.item(None); pk._mats.clear()
    FRm, upw, hw = N.frames(G)
    before = set(bpy.data.objects)
    if c.get('umbrella'):
        w = upw(G['arms'][-1][2]); bw_ = B(w)
        do4.du_tay((bw_.x, bw_.y, bw_.z - .02), R=.5, col=c['umbrella'], tilt=(.55, -.15))
    if c.get('basket'):
        m = (upw(G['arms'][-1][2]) + upw(G['arms'][1][2])) / 2; bm = B(m)
        do4.gio_du((bm.x, bm.y - .04, bm.z - .64), rope_len=0)
    if c.get('roll'):
        m = (upw(G['arms'][-1][2]) + upw(G['arms'][1][2])) / 2; bm = B(m)
        do4.bat_cuon((bm.x, bm.y - .05, bm.z - .06))
    for o in [o for o in bpy.data.objects if o not in before]:
        for cl in list(o.users_collection): cl.objects.unlink(o)
        coll.objects.link(o)
N.HOOKS.append(hook)
CUR = {}

POSES = {
 'may_mua': lambda: N3.pose('may_mua', bend=.04, nod=.04, yaw=-.2, tilt=.05, mouth='open', aR=((-.24, 1.0, .14), (-.12, 1.16, .28), (1, 0, 0)), aL=((.24, .96, -.02), (.27, .76, .04), (-1, 0, 0))),
 'cohai_mua': lambda: N3.pose('cohai_mua', bend=.05, nod=.06, yaw=.2, mouth='open', aR=((-.24, .92, .1), (-.14, .96, .3), (0, 1, .3)), aL=((.26, .96, 0), (.2, .86, .12), (-1, 0, 0))),
 'bena_mua': lambda: N3.pose('bena_mua', bend=.1, nod=.32, yaw=.05, tilt=.06, mouth='open', aR=((-.15, .64, .12), (-.04, .72, .26), (1, 0, 0)), aL=((.15, .64, .12), (.04, .72, .26), (-1, 0, 0))),
 'chunam_mua': lambda: N3.pose('chunam_mua', sit=.86, bend=-.04, nod=.05, yaw=.35, mouth='smile', knee=(.6, .3), ankle=(.07, .26), kx=.1,
                               aR=((-.24, .72, .12), (-.12, .62, .3), (0, -1, 0)), aL=((.26, .74, .08), (.16, .62, .3), (0, -1, 0)), bike=True),
 'chutu_mua': lambda: N3.pose('chutu_mua', bend=.06, nod=.15, yaw=-.1, mouth='smile', aR=((-.22, .95, .12), (-.1, .93, .3), (0, 1, 0)), aL=((.22, .95, .12), (.1, .93, .3), (0, 1, 0))),
}

if __name__ == '__main__':
    cid = sys.argv[1]; out = sys.argv[2]
    P = POSES[cid](); N.CHARS[cid]['pose'] = P; N3.CUR['P'] = P; CUR['c'] = N.CHARS[cid]
    os.chdir(HERE)
    N.run(cid, out, '--glb' in sys.argv)
