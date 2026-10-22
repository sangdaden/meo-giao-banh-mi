"""G10 · Chủ Nhật Hội mèo: Bà Mướp (mèo mới) + 7 mèo trong hội lấy từ 19 giống có sẵn, phong cách D.
Dùng chung lõi dựng mèo của luồng "Skin mèo và phụ kiện" (meo-3d/skins: catcore, breeds, acc, blend).

Chạy: python3 hoi.py <outdir> <id,id..|all> [views] [--noglb]
  views mặc định: q34,front,side,back (thêm face cho cận mặt). Ảnh nền trong suốt để ghép lưới đo và bóng Bơ.
"""
import sys, os, json, copy, numpy as np
SK = '/mnt/project-files/meo-3d/skins'
sys.path.insert(0, SK)
import catcore as cc
from breeds import BREEDS
from sdflib import v, ellipsoid, sphere, roundcone, smin, smax, chain, catmull, hexc, sstep
from parts import Part, torus, shell, box

# ---------------- Bà Mướp: mèo mướp già, xám vằn bạc màu, mắt hiền, hơi mập, đeo kính lão ----------------
BREEDS['bamuop'] = dict(
    body=(1.15, 1.02), leg=.95, headk=(1.04, 1.0, .99), jowl=.25, ear=dict(L=.088, r=(.052, .013)),
    set=dict(pattern='tabby', stripes='soft', pouch=.035, frost=1.0,
             col=dict(fur='#A8A49C', fur2='#7A746C', belly='#EEEAE2', earin='#D7A6A0', nose='#B47A78', line='#3E3632', blush='#E8A49A'),
             blush=.32,
             eye=dict(iris=('#DCD27E', '#9C8C36'), ring='#5C5020', r=(.0304, .0248, .0166), lid=.16, smile=.24, pupilw=.46),
             pose=dict(yaw=.28, pitch=-.02, roll=.06, pivot=(0, .34, .12))))

# Đổi trong BASE (dùng chung): thêm bụng xệ (pouch) và lông bạc quanh mõm, mày (frost) cho mèo già.
_torso = cc.torso_sdf
def torso_sdf(p):
    d = _torso(p); S = cc.S
    k = S.get('pouch', 0)
    if k:
        bc, br = S['body']
        d = smin(d, ellipsoid(p, v(bc[0], bc[1] - br[1] * .72, bc[2] - br[2] * .2), v(br[0] * .8, k * 1.6, br[2] * .62)), .045)
    return d
cc.torso_sdf = torso_sdf

_colors = cc.colors
def colors(V, N):
    col = _colors(V, N); S = cc.S
    f = S.get('frost', 0)
    if not f: return col
    q = cc.head_local(V); hc, hr = S['head']; pc, prr = S['pads']; ec = S['eye']['c']
    pads = np.minimum(np.linalg.norm(q - v(pc[0], *pc[1:]), axis=1), np.linalg.norm(q - v(-pc[0], *pc[1:]), axis=1))
    muz = sstep(prr + .04, prr + .012, pads)
    brow = np.zeros(len(V), np.float32)
    for s in (-1, 1):
        b = v(s * ec[0] * 1.05, ec[1] + .03, ec[2] - .004)
        brow = np.maximum(brow, sstep(.022, .008, np.linalg.norm((q - b) * v(1, 1.8, 1), axis=1)))
    chin = sstep(.04, .015, np.linalg.norm((q - v(0, pc[1] - .04, pc[2] - .025)) * v(1, 1.2, 1), axis=1))
    m = np.clip(np.maximum.reduce([muz * .55, brow * .6, chin * .5]), 0, 1) * f
    # lông bạc lấm tấm, không phủ đều
    m = m * (.75 + .25 * np.sin(V[:, 0] * 900) * np.sin(V[:, 1] * 870 + 1.3))
    return col * (1 - m[:, None]) + hexc('#F4F1EA') * m[:, None]
cc.colors = colors

# ---------------- 2 món mới của Bà Mướp ----------------
def _acc():
    import acc
    return acc

def kinhlao():
    """Kính lão nửa vầng trăng, gọng vàng mảnh, đeo trễ xuống sống mũi; dây kính hạt cườm vòng ra sau gáy."""
    A_ = _acc(); hc, hr = A_.H(); ec, er = A_.eyes_xyz()
    A = [v(s * ec[0] * 1.0, ec[1] - .021, ec[2] + er[2] + .024) for s in (-1, 1)]
    def half(p, c, grow=0.):
        q = p - c; ell = np.sqrt((q[..., 0] / (.03 + grow)) ** 2 + (q[..., 1] / (.024 + grow)) ** 2) - 1
        cut = q[..., 1] - (.004 + grow * .3)            # chỉ giữ nửa dưới (mắt kính nửa vầng trăng)
        return np.maximum(ell * .024, cut)
    def rim(p):
        d = np.minimum.reduce([smax(np.abs(half(p, c)) - .0022, np.abs((p - c)[..., 2]) - .0025, .0008) for c in A])
        m = (A[0] + A[1]) / 2 + v(0, .002, .004)
        br = chain(p, [A[0] + v(.028, .004, 0), m, A[1] + v(-.028, .004, 0)], [.0022] * 3, .001)
        tm = np.minimum.reduce([chain(p, [A[i] + v(s * .03, .004, -.002), v(s * hr[0] * 1.0, ec[1] + .006, hc[2] + .03), v(s * hr[0] * .93, ec[1] + .0, hc[2] - .03)], [.0022] * 3, .002)
                                for i, s in ((0, -1), (1, 1))])
        return np.minimum.reduce([d, br, tm])
    lens = lambda p: np.minimum.reduce([smax(half(p, c, -.001), np.abs((p - c)[..., 2]) - .0011, .0006) for c in A])
    return [Part('Gong_KinhLao', rim, hc - .2, hc + .2, '#C9A24A', 'metal', metal=1, rough=.32, head=True, h=.0009),
            Part('Trong_KinhLao', lens, hc - .2, hc + .2, '#DDEBEE', 'glass', alpha=.3, head=True, h=.0009)]

def daykinh():
    """Dây kính: chuỗi hạt cườm nhỏ từ hai càng kính rủ xuống, vòng sau gáy (dựng ở toạ độ thế giới, gắn xương head)."""
    A_ = _acc(); S = cc.S; hc, hr = A_.H(); ec, er = A_.eyes_xyz()
    ends = [cc.head_world(v(s * hr[0] * .93, ec[1], hc[2] - .03)) for s in (-1, 1)]
    c, n = v(*S['neck'][0]), v(*S['neck'][1]); n = n / np.linalg.norm(n)
    nape = cc.surf_point(c, (0, .25, -1), .012)
    sides = [cc.surf_point(c, (s, -.15, -.25), .012) for s in (-1, 1)]
    pts = catmull([ends[0], sides[0], nape, sides[1], ends[1]], 10)
    beads = pts[::2]
    def sdf(p):
        d = chain(p, list(pts), [.0011] * len(pts), .001)
        return np.minimum(d, np.minimum.reduce([sphere(p, b, .0032) for b in beads]))
    lo = pts.min(0) - .02; hi = pts.max(0) + .02
    return [Part('Day_Kinh', sdf, lo, hi, '#B8863A', 'metal', metal=1, rough=.4, h=.0009)]

def khanchoang():
    """Khăn choàng len màu mận khoác vai, viền kem, buộc nơ nhỏ trước ngực."""
    S = cc.S; c = v(*S['neck'][0]); n = v(*S['neck'][1]); n = n / np.linalg.norm(n)
    def sdf(p):
        b = cc.body_sdf(p)
        sh = shell(b, .002, .009)
        h = (p - c) @ n                                   # khoảng cách dọc theo trục cổ (âm = xuống vai)
        r = np.linalg.norm((p - c) - h[..., None] * n, axis=-1)
        band = smax(h - .012, -(h + .07 + .03 * sstep(.0, .1, p[..., 2] - c[2] + .05)), .01)
        d = smax(sh, band, .006)
        d = smax(d, r - .17, .01)
        k = cc.knot_point(v(0, -.35, .94))
        d = smin(d, ellipsoid(p, k, v(.02, .016, .014)), .006)
        for s in (-1, 1):
            d = smin(d, ellipsoid(p, k + v(s * .022, .002, -.002), v(.018, .012, .008)), .004)
        return d
    def knit(V, N):
        h = (V - c) @ n
        rib = sstep(.2, .8, np.sin(np.arctan2(V[:, 0], V[:, 2] - c[2]) * 70) * .5 + .5) * .1
        edge = sstep(-.06, -.07, h)
        col = np.where(edge[:, None] > .5, hexc('#F1E6D2'), hexc('#7E3550'))
        return col * (1 - rib[:, None])
    return [Part('Khan_Choang', sdf, c - .2, c + .2, None, 'cloth', colorfn=knit, h=.0026)]

NEW_ACC = dict(kinhlao=kinhlao, daykinh=daykinh, khanchoang=khanchoang)

# ---------------- 8 mèo trong hội ----------------
# id: (tên, giống, giới, phụ kiện, tính cách, vai)
CATS = {
    'ba_muop': ('Bà Mướp', 'bamuop', 'cai', ['kinhlao', 'daykinh', 'khanchoang'], 'chậm rãi, hay cười', 'chủ hội: ngồi thùng gỗ sân khấu, ra chủ đề, trao huy chương'),
    'mit':     ('Mít', 'xiem', 'cai', ['kinhphicong'], 'nhanh nhẹn, ngại nước', 'đối thủ đua mái nhà, đội tiếp sức đối thủ'),
    'bot':     ('Bột', 'khoaimon', 'duc', ['khanran'], 'chắc chân, không bao giờ trượt', 'đối thủ đua mái nhà, nhảy thùng, đội tiếp sức đối thủ'),
    'mun':     ('Mun', 'mun', 'duc', ['chuong'], 'lặng lẽ, giỏi trốn', 'trốn tìm (chuông cổ kêu khi rón rén lại gần), đội tiếp sức đối thủ, mèo lạ sân thượng Thứ Bảy'),
    'tuyet':   ('Tuyết', 'tuyet', 'cai', ['vuongmien'], 'điệu đà', 'thi trang phục, khán giả'),
    'lac':     ('Lạc', 'vobanh', 'duc', ['nonsinhnhat'], 'vui tính, nhảy kém', 'nhảy thùng (luôn hạng chót, cổ vũ to nhất), khán giả'),
    'gung':    ('Gừng', 'que', 'duc', ['bangdo'], 'hăng hái', 'đội tiếp sức của Bơ, mèo lạ sân thượng Thứ Bảy'),
    'sua':     ('Sữa', 'suadac', 'cai', ['hoadambut'], 'hiền, chậm', 'đội tiếp sức của Bơ'),
}
ORDER = list(CATS)
# Bơ chuẩn chỉ để làm bóng so cỡ trên ảnh chiếu thẳng (không thuộc hội)
EXTRA = {'bo': ('Bơ', 'bo', 'duc', ['khando'], '', '')}
def cat(cid): return CATS.get(cid) or EXTRA[cid]

def acc_parts(aid):
    if aid in NEW_ACC: return NEW_ACC[aid](), {}
    import acc
    return acc.ACC[aid]()

def setup(cid):
    name, bid, g, accs, *_ = cat(cid)
    S = cc.make_S(BREEDS[bid], g)
    if BREEDS[bid].get('ear', {}).get('fold'): S['ear']['fold'] = True
    if any(a in ('mucoi', 'nonla', 'muphuthuy') for a in accs): S['ear'].update(up=(.95, .3, -.2), L=.05, th=2.8)
    cc.configure(S)
    return S

def measure(cid):
    S = setup(cid); k = S['size']
    tp = catmull(S['tail'][0], 12); tl = float(np.sum(np.linalg.norm(np.diff(tp, axis=0), axis=1)))
    if S.get('bob'): tl = .06
    nose = cc.head_world(v(*S['nose'][0]))[2] + .01
    rump = S['body'][0][2] - S['body'][1][2]; hb = float(nose - rump)
    base, up, fwd, rt = cc.ear_frame(1); tip = cc.head_world(base + up * S['ear']['L'])
    return dict(hb=round(hb * k, 3), tail=round(tl * k, 3), ratio=round(tl / hb, 2), h=round(float(tip[1] + S['ear']['r'][1]) * k, 3),
                tr=[round(S['tail'][1][0] * 2 * k * 100, 1), round(S['tail'][1][1] * 2 * k * 100, 1)], size=k,
                w=round(float(S['body'][1][0] * 2 * k), 3))

def run(out, ids, views=('q34', 'front', 'side', 'back'), glb=True):
    import blend as bl
    from parts import to_blender
    os.makedirs(out, exist_ok=True)
    for cid in ids:
        S = setup(cid)
        (V, F, N, C), _ = cc.build_body()
        bl.reset(); fl, cam = bl.scene_setup(); sc = bl.bpy.context.scene
        sc.render.film_transparent = True
        fl.is_shadow_catcher = True
        coll = bl.bpy.data.collections.new('Meo'); sc.collection.children.link(coll)
        kind = S['mat']
        ob = bl.make_mesh('Than', V, F, C, coll=coll)
        ob.data.materials.append(bl.material('Long', attr=True, kind={'fur': 'fur', 'skin': 'skin', 'metal': 'metal'}[kind]))
        bl.eyes(coll)
        parts_meta = [dict(name='Than', tris=int(len(F)), kind=kind)]
        for aid in cat(cid)[3]:
            pts, opt = acc_parts(aid)
            for pt in pts:
                o = to_blender(pt, coll)
                if o: parts_meta.append(dict(name=pt.name, acc=aid, tris=len(o.data.polygons), color=pt.color, kind=pt.kind))
        k = S['size']
        for o in coll.objects: o.scale = tuple(x * k for x in o.scale); o.location = o.location * k
        bl.VD['mat'] = ((.11 * k, -.8 * k, .46 * k), None, 68, (0, -.16 * k, .42 * k))
        for vw in views: bl.render(f'{out}/{cid}_{vw}.png', vw)
        if glb: bl.export_glb(f'{out}/{cid}.glb', [o for o in coll.objects if o.type in ('MESH', 'CURVE')])
        m = measure(cid); m.update(parts=parts_meta, sockets=cc.sockets())
        json.dump(m, open(f'{out}/meta_{cid}.json', 'w'), ensure_ascii=False)
        print('done', cid, m['hb'], m['tail'], m['ratio'], flush=True)

if __name__ == '__main__':
    out = sys.argv[1]; ids = ORDER if sys.argv[2] == 'all' else sys.argv[2].split(',')
    vws = sys.argv[3].split(',') if len(sys.argv) > 3 and not sys.argv[3].startswith('--') else ['q34', 'front', 'side', 'back']
    run(out, ids, vws, glb='--noglb' not in sys.argv)
