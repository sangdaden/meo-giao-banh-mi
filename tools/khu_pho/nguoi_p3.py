"""Người qua đường (gói P3 "Thiết kế lại khu phố", Sang duyệt 22/10 10:17 UTC): 8 người, 8 bộ đổi đồ (_b), 5 áo mưa (_mua),
2 bản đội nón bảo hiểm khi đi xe (_xe: Anh Phúc lái, Bé Khoa ngồi sau xe mẹ).
Chép CHARS, phụ kiện liền thân (ba lô, túi xách, khăn quàng, tai nghe) và dáng từ p3nguoi.py của trang phác thảo
(/mnt/project-files/thiet-ke-lai-khu-pho/p3-nguoi-qua-duong/). Xe máy, bậc xe buýt chỉ để render, không ở đây;
đồ cầm tay (điện thoại, ly trà đá, vé số, hộp cơm, túi che đầu) là glb rời trong do_cam_p3.py.
Tay trong DANG cho bằng mét thế giới (x trái(+)/phải(-) của nhân vật, y lên, z trước), như nguoi3.py."""
import math
import copy
import numpy as np
import nguoi as N
import nguoi3 as N3
import nguoi4  # noqa: F401  áo mưa (coat_kind) dựng trong nguoi4.build
from nguoi import v, ellipsoid, roundcone, smin, smax, chain, box, nrm
from nguoi3 import pose

def C(**kw): kw.setdefault('pose', {}); return kw
CH = {
 'qd_ongtd': C(fem=False, name='Ông Hai tập thể dục', role='Đi bộ thể dục sáng sớm, ghé quán trà đá', h=1.62, old=True, build=dict(bw=.92, belly=1.0, hip=.95, legr=.9, armr=.9),
   skin='#C99272', hair=dict(style='short', col='#DCD8D2'), top=dict(kind='tee', col='#F4F1EA', sleeve='short'), bottom=dict(kind='pants', col='#2F3B57'),
   shoe='#F1ECE2', sandal=False, eye=('#8A5A36', '#3E2416'), extras=['towel']),
 'qd_vanphong': C(name='Chị Vy văn phòng', role='Đi làm bằng xe buýt, sáng đi chiều về', h=1.6, build=dict(bw=.92, belly=.92, hip=1.0, legr=.94, armr=.9),
   skin='#EDBB95', hair=dict(style='ponytail', col='#2C1E18'), top=dict(kind='shirt', col='#BFD8EA', sleeve='long'), bottom=dict(kind='pants', col='#3A3F4A'),
   shoe='#2E2A28', sandal=False, eye=('#A06A34', '#4A2A14'), extras=['earring', 'tuixach'], tui='#B8673A'),
 'qd_hocsinh': C(fem=False, name='Bé Khoa học sinh', role='Học sinh lớp 4, chiều tan trường', h=1.3, kid=True, build=dict(bw=.95, belly=.95, hip=.95, legr=1.0, armr=1.0),
   skin='#E3AE88', hair=dict(style='short', col='#1E1714'), top=dict(kind='shirt', col='#F7F5F0', sleeve='short'), bottom=dict(kind='shorts', col='#2F3B57'),
   shoe='#E9E2D2', sandal=False, eye=('#A87038', '#4A2A14'), extras=['khanquang', 'balo'], balo='#3F8FD0'),
 'qd_sinhvien': C(fem=False, name='Anh Phúc sinh viên', role='Đi xe buýt tới trường, ngồi cà phê vỉa hè', h=1.7, build=dict(bw=1.0, belly=.92, hip=.96, legr=.98, armr=.96),
   skin='#D9A07A', hair=dict(style='short', col='#2A1D18'), top=dict(kind='tee', col='#8E9AA6', sleeve='short'), bottom=dict(kind='pants', col='#4D6A8A'),
   shoe='#F1ECE2', sandal=False, eye=('#9A6534', '#43271A'), extras=['balo', 'tainghe'], balo='#2E2A30', helmet_ride='#2E6FA8'),
 'qd_veso': C(name='Cô Tám vé số', role='Đi rong bán vé số, trưa và tối', h=1.5, old=True, build=dict(bw=.95, belly=1.05, hip=1.05, legr=.9, armr=.92),
   skin='#D49A74', hair=dict(style='bun', col='#6E655A', nonla=True), top=dict(kind='baba', col='#C9B48A'), bottom=dict(kind='pants', col='#3D3F48'),
   shoe='#6A4A3A', eye=('#8A5A36', '#3E2416'), extras=['fannypack']),
 'qd_giaohang': C(fem=False, name='Anh Đạt giao hàng', role='Chạy xe giao hàng, ghé cửa nhà, gọi điện cho khách', h=1.68, build=dict(bw=1.02, belly=.95, hip=.98, legr=1.0, armr=1.0),
   skin='#C68A60', hair=dict(style='short', col='#1E1714', helmet='#3E8E5A'), top=dict(kind='shirt', col='#4FA35A', sleeve='long'), bottom=dict(kind='pants', col='#2E2A28'),
   shoe='#2E2A28', sandal=False, eye=('#8A5A2E', '#3A2214'), extras=[]),
 'qd_congnhan': C(fem=False, name='Chú Bảy công nhân', role='Thợ hồ ở căn nhà đang xây, trưa ngồi ăn cơm hộp', h=1.66, build=dict(bw=1.1, belly=1.05, hip=1.0, legr=1.08, armr=1.1),
   skin='#B97E56', hair=dict(style='short', col='#2A1D18', helmet='#F2C230'), top=dict(kind='shirt', col='#E0782F', sleeve='long', stripes='#F2E3B8'), bottom=dict(kind='pants', col='#5A5A52'),
   shoe='#4A3A2E', sandal=False, eye=('#8A5A2E', '#3A2214'), extras=['towel']),
 'qd_mehoa': C(name='Chị Hoa chở con', role='Chạy xe đón con tan trường, ghé tạp hóa', h=1.57, build=dict(bw=.94, belly=.96, hip=1.04, legr=.95, armr=.92),
   skin='#E8B48E', hair=dict(style='ponytail', col='#2C1E18', helmet='#F2F0EA'), top=dict(kind='shirt', col='#E58AA0', sleeve='long'), bottom=dict(kind='pants', col='#6B5A8A'),
   shoe='#E9E2D2', eye=('#A06A34', '#4A2A14'), extras=['earring']),
}
N.CHARS.update(CH)

def mk(base, cid, name, role, **kw):
    c = copy.deepcopy(N.CHARS[base]); c.update(name=name, role=role, base=base)
    for k, val in kw.items():
        if isinstance(val, dict) and isinstance(c.get(k), dict): c[k].update(val)
        else: c[k] = val
    N.CHARS[cid] = c; return c

# ---- đổi đồ: cùng người, khác áo / nón / túi (bản game đổi bằng màu đỉnh, không thêm file)
mk('qd_ongtd', 'qd_ongtd_b', 'Ông Hai (áo xanh, nón kết)', 'Đổi áo', top=dict(col='#9CC5E0'), hair=dict(cap='#F4F1EA'), bottom=dict(kind='shorts', col='#6B6A55'))
mk('qd_vanphong', 'qd_vanphong_b', 'Chị Vy (áo vàng, túi đen)', 'Đổi áo', top=dict(col='#F2D27A'), bottom=dict(col='#F1ECE2'), tui='#2E2A30')
mk('qd_hocsinh', 'qd_hocsinh_b', 'Bé Ngân học sinh', 'Bạn nữ cùng lớp', fem=True, hair=dict(style='pigtails', col='#2C1E18', tie='#E86AAE'), bottom=dict(kind='skirt', col='#2F3B57'), balo='#E86AAE', h=1.28)
mk('qd_sinhvien', 'qd_sinhvien_b', 'Anh Phúc (nón kết, áo xanh lá)', 'Đổi áo', top=dict(col='#3E8C5C'), hair=dict(cap='#C8412F'), extras=['balo'], balo='#C9B48A')
mk('qd_veso', 'qd_veso_b', 'Cô Tám (áo hoa, không nón)', 'Đổi áo', top=dict(col='#8C5A9A', floral='#F2C14E'), hair=dict(style='perm', col='#6E655A', nonla=False))
mk('qd_giaohang', 'qd_giaohang_b', 'Anh Đạt (áo cam)', 'Đổi áo khoác', top=dict(col='#E8913A'), hair=dict(helmet='#E8913A'))
mk('qd_congnhan', 'qd_congnhan_b', 'Chú Bảy (áo xanh, nón trắng)', 'Đổi áo', top=dict(col='#2F6FA8', stripes='#F2C230'), hair=dict(helmet='#F4F1EA'))
mk('qd_mehoa', 'qd_mehoa_b', 'Chị Hoa (áo xanh, nón hồng)', 'Đổi áo', top=dict(col='#8AC6E8'), hair=dict(helmet='#E58AA0'), bottom=dict(col='#2E3640'))
# ---- áo mưa Thứ Tư (cùng kiểu áo mưa của nguoi4.py)
mk('qd_vanphong', 'qd_vanphong_mua', 'Chị Vy (áo mưa cánh dơi)', 'Thứ Tư', coat='#5FB3B6', coat_kind='poncho', hood='up')
mk('qd_hocsinh', 'qd_hocsinh_mua', 'Bé Khoa (áo mưa trùm cặp)', 'Thứ Tư', coat='#3F8FD0', coat_kind='poncho', hood='up')
mk('qd_congnhan', 'qd_congnhan_mua', 'Chú Bảy (áo mưa bộ)', 'Thứ Tư', coat='#F2C230', coat_kind='jacket', hood='helmet')
mk('qd_giaohang', 'qd_giaohang_mua', 'Anh Đạt (áo mưa bộ, đang chạy)', 'Thứ Tư', coat='#2E6E5A', coat_kind='jacket', hood='helmet')
mk('qd_mehoa', 'qd_mehoa_mua', 'Chị Hoa (áo mưa cánh dơi trên xe)', 'Thứ Tư', coat='#E86AAE', coat_kind='poncho', hood='helmet')

N.EXTRA_PAL.update(khautrang='#E4EEF2', khanquang='#D2332A', tainghe='#2E2A30', veso='#2E7C80', ve='#F4E6B0', ve2='#E58AA0', trada='#C98A3A', ly='#D8E6E4',
                   hopcom='#F4F1EA', goi='#C99A5A', dt='#2E3640', dt2='#7FB3D9', ong='#F2F0EA')
N.GROUP.update(balo='cloth', balo2='hard', tuixach='hard', khautrang='cloth', khanquang='cloth', tainghe='hard', veso='hard', ve='cloth', ve2='cloth', trada='glass', ly='glass',
               hopcom='hard', goi='hard', dt='hard', dt2='glass', ong='hard')
_pal = N.palette
def palette(c):
    P = _pal(c); b = c.get('balo', '#3F8FD0'); P['balo'] = b; P['balo2'] = '#2E2A30'; P['tuixach'] = c.get('tui', '#B8673A'); return P
N.palette = palette

# ---------------------------------------------------------------- phụ kiện trên người + đồ cầm tay
_b = N.build
def build(c, posed):
    parts, G, FR, headw = _b(c, posed)
    s = G['s']; hc, hr = G['head_c'], G['head_r']; bw = c['build']['bw']; bel = c['build']['belly']; hip = c['build']['hip']
    sc = lambda *a: v(*a) * s
    def add(name, fn, mat, frame, k=.004, sep=False): parts.append(dict(name=name, fn=fn, mat=mat, frame=frame, k=k, sep=sep))
    ex = c.get('extras', [])
    if 'balo' in ex:   # ba lô / cặp sau lưng, hai quai qua vai
        add('balo', lambda p: box(p, sc(0, .99, -.155 * max(1, bel)), sc(.125, .155, .06), .035 * s), 'balo', 'up', k=.02 * s)
        add('balo2', lambda p: box(p, sc(0, .9, -.215 * max(1, bel)), sc(.09, .06, .015), .012 * s), 'balo2', 'up', k=.006)
        for sd in (-1, 1):
            add('balo', (lambda sd: lambda p: chain(p, [sc(sd * .08, 1.1, -.13), sc(sd * .09, 1.235, -.03), sc(sd * .1, 1.17, .1 * bw), sc(sd * .105, .99, .1 * max(bw, bel))], [.012 * s] * 4, .004))(sd), 'balo2', 'up', k=.006)
    if 'tuixach' in ex:   # túi đeo chéo vai trái xuống hông phải
        add('tuixach', lambda p: box(p, sc(-.19 * hip, .8, .03), sc(.1, .075, .03), .02 * s), 'tuixach', 'up', k=.008)
        add('tuixach', lambda p: chain(p, [sc(.1, 1.22, -.01), sc(.02, 1.08, .118 * max(bw, bel)), sc(-.1, .93, .11 * max(bw, bel)), sc(-.18 * hip, .87, .05)], [.008 * s] * 4, .003), 'tuixach', 'up', k=.004)
    if 'khautrang' in ex:   # khẩu trang vải che mũi miệng, chừa mắt
        def mask(p):
            e = ellipsoid(p, hc + v(0, -hr[1] * .05, 0), hr * v(1.03, 1.03, 1.07))
            cut = np.maximum.reduce([p[..., 1] - (hc[1] - hr[1] * .2), (hc[1] - hr[1] * .9) - p[..., 1], (hc[2] + hr[2] * .1) - p[..., 2]])
            return smax(np.abs(e) - .006 * s, cut, .01 * s)
        add('khautrang', mask, 'khautrang', 'head', k=.003)
        for sd in (-1, 1):
            add('khautrang', (lambda sd: lambda p: chain(p, [hc + v(sd * hr[0] * .82, -hr[1] * .32, hr[2] * .42), hc + v(sd * hr[0] * 1.03, -hr[1] * .12, -hr[2] * .02)], [.004 * s] * 2, .002))(sd), 'khautrang', 'head', k=.002)
    if 'khanquang' in ex:   # khăn quàng đỏ: vòng cổ + nút + hai vạt
        def khan(p):
            q = p - sc(0, 1.205, -.01); r = np.linalg.norm(q[..., [0, 2]] * np.array([1, 1.15], np.float32), axis=-1)
            ring = np.sqrt((r - .07 * s) ** 2 + q[..., 1] ** 2) - .016 * s
            knot = ellipsoid(p, sc(0, 1.17, .085 * bw), sc(.026, .022, .018))
            tails = np.minimum(roundcone(p, sc(0, 1.16, .09 * bw), sc(-.045, 1.04, .115 * bw), .02 * s, .006 * s), roundcone(p, sc(0, 1.16, .09 * bw), sc(.04, 1.05, .113 * bw), .018 * s, .006 * s))
            return smin(smin(ring, knot, .01 * s), tails, .01 * s)
        add('khanquang', khan, 'khanquang', 'up', k=.006)
    if 'tainghe' in ex:   # tai nghe chụp tai, quai qua đỉnh đầu
        add('tainghe', lambda p: chain(p, [hc + v(-hr[0] * 1.08, -hr[1] * .05, 0), hc + v(-hr[0] * .8, hr[1] * .85, 0), hc + v(0, hr[1] * 1.13, 0), hc + v(hr[0] * .8, hr[1] * .85, 0), hc + v(hr[0] * 1.08, -hr[1] * .05, 0)], [.008 * s] * 5, .004), 'tainghe', 'head', k=.004)
        for sd in (-1, 1):
            add('tainghe', (lambda sd: lambda p: ellipsoid(p, hc + v(sd * hr[0] * 1.08, -hr[1] * .12, -hr[2] * .05), sc(.018, .032, .03)))(sd), 'tainghe', 'head', k=.004)
    if not posed: return parts, G, FR, headw
    P = c['pose']
    if P.get('lai') or P.get('datxe') or P.get('noseat'): parts[:] = [p for p in parts if p['name'] != 'stool']
    WR = {sd: G['arms'][sd][2] for sd in (1, -1)}; EL = {sd: G['arms'][sd][1] for sd in (1, -1)}
    def prop(name, fn, mat): parts.append(dict(name=name, fn=fn, mat=mat, frame='up', k=.002, sep=True))
    def ahead(sd, k=.06): return WR[sd] + nrm(WR[sd] - EL[sd]) * k * s
    mid = (WR[1] + WR[-1]) / 2
    for pr in (P.get('prop') or '').split('+'):
        if pr == 'dt':       # điện thoại cầm hai tay trước ngực, màn hình ngửa lên
            cc = mid + v(0, .06, .035)   # dựng gần đứng, màn hình quay về mặt người cầm
            prop('dt', lambda p: box(p, cc, v(.04, .078, .007), .006), 'dt')
            prop('dt2', lambda p: box(p, cc + v(0, .002, -.006), v(.034, .068, .002), .002), 'dt2')
        if pr == 'dttai':    # điện thoại áp tai phải
            cc = hc * 0 + WR[-1] + v(.0, .04, .0)
            prop('dt', lambda p: box(p, cc, v(.008, .07, .036), .006), 'dt')
        if pr == 'lyda':     # ly trà đá nhựa
            cc = ahead(-1, .05) + v(0, -.02, 0)
            prop('ly', lambda p: smax(np.abs(roundcone(p, cc + v(0, -.05, 0), cc + v(0, .07, 0), .036, .044)) - .003, p[..., 1] - cc[1] - .07, .002), 'ly')
            prop('trada', lambda p: smax(roundcone(p, cc + v(0, -.047, 0), cc + v(0, .045, 0), .033, .04), p[..., 1] - cc[1] - .045, .002), 'trada')
        if pr == 'veso':     # bảng vé số kẹp tay trái: tấm gỗ + 4 hàng vé
            cc = WR[1] + v(-.07, .03, .06)
            prop('veso', lambda p: box(p, cc, v(.11, .15, .006), .006), 'veso')
            for i in range(4):
                prop('ve' if i % 2 else 've2', (lambda i: lambda p: box(p, cc + v(0, .1 - i * .066, .009), v(.095, .026, .003), .002))(i), 've' if i % 2 else 've2')
        if pr == 'quatve':   # xấp vé xòe trên tay phải, chìa ra mời
            a = ahead(-1, .05)
            for i in range(4):
                ang = -.5 + i * .33
                prop('ve', (lambda ang, i: lambda p: box(p, a + v(math.sin(ang) * .05, .035 + math.cos(ang) * .03, .004 * i), v(.024, .045, .002), .002))(ang, i), 've' if i % 2 else 've2')
        if pr == 'hopcom':   # hộp cơm xốp mở nắp tay trái + đôi đũa tay phải
            cc = WR[1] + v(-.06, .03, .04)
            prop('hopcom', lambda p: smax(box(p, cc, v(.085, .032, .065), .01), -box(p, cc + v(0, .02, 0), v(.075, .03, .055), .008), .004), 'hopcom')
            prop('hopcom', lambda p: box(p, cc + v(0, .06, -.07), v(.085, .06, .008), .008), 'hopcom')
            a = ahead(-1, .02)
            prop('ong', lambda p: np.minimum(roundcone(p, a, a + v(.08, -.05, .1), .004, .003), roundcone(p, a + v(.01, 0, 0), a + v(.09, -.04, .1), .004, .003)), 'ong')
        if pr == 'goi':      # thùng hàng các-tông ôm tay trái
            cc = WR[1] + v(-.08, .08, .02)
            prop('goi', lambda p: box(p, cc, v(.12, .09, .1), .008), 'goi')
        if pr == 'tuidau':   # giơ túi xách lên đầu che mưa
            cc = mid + v(0, .05, -.02)
            prop('tuixach', lambda p: box(p, cc, v(.15, .045, .1), .025), 'tuixach')
    return parts, G, FR, headw
N.build = build

# ---------------------------------------------------------------- dáng
walk = dict(L=((.43, .1), (.08, .2)), R=((.42, -.06), (.12, -.2)))
run_ = dict(L=((.47, .22), (.14, .3)), R=((.38, -.12), (.26, -.32)))
wide = dict(L=((.45, .05), (.1, .02)), R=((.45, -.05), (.1, -.02)))
step = dict(L=((.77, .34), (.43, .36)), R=((.42, -.06), (.1, -.16)))
def F(cid): return N.CHARS[cid]['h'] / 1.58
def hang(sd, f): return ((sd * .25 * f, .95 * f, -.02), (sd * .27 * f, .73 * f, .04), (-sd, 0, 0))
def swing(sd, f, fwd): return ((sd * .24 * f, .96 * f, .1 * fwd), (sd * .25 * f, .76 * f, .2 * fwd), (-sd, 0, 0))
def strap(sd, f): return ((sd * .2 * f, .95 * f, .02), (sd * .11 * f, 1.07 * f, .1 * f), (-sd, 0, .3))
def hips(sd, f): return ((sd * .33 * f, .98 * f, -.06 * f), (sd * .17 * f, .86 * f, .0), (0, 0, sd * 1.0))
def wave(sd, f): return ((sd * .36 * f, 1.03 * f, .06), (sd * .37 * f, 1.23 * f, .12), (0, 0, 1))
GRIP = dict(aR=((-.26, 1.16, .2), (-.3, 1.1, .44), (0, -1, 0)), aL=((.26, 1.16, .2), (.3, 1.1, .44), (0, -1, 0)))
LAI = dict(sit=.95, knee=(.8, .33), ankle=(.45, .27), kx=.19, lai=True)

def DANG(key):
    """'<id>:<dáng>' hoặc '<id>:<dáng>@<người mẫu>' (mượn dáng của người khác, tay co giãn theo người đang dựng)."""
    cid, dk = key.split(':')
    if cid not in IDS:
        return _D3(key)
    dk, _, mau = dk.partition('@')
    base = mau or N.CHARS[cid].get('base', cid); f = F(cid)
    D = {
     # Ông Hai: đi bộ vung tay / vươn vai / ngồi ghế nhựa uống trà đá
     'qd_ongtd:dibo': lambda: pose(cid, bend=.02, nod=-.02, yaw=0, mouth='smile', legs=walk, aR=((-.24 * f, .97 * f, .16), (-.2 * f, 1.08 * f, .34), (1, 0, .2)), aL=((.25 * f, .95 * f, -.13), (.27 * f, .76 * f, -.22), (-1, 0, 0))),
     'qd_ongtd:vuonvai': lambda: pose(cid, bend=-.08, nod=-.25, mouth='o', brow=-.3, legs=wide, aR=((-.24 * f, 1.47 * f, .02), (-.09 * f, 1.7 * f, .05), (1, 0, 0)), aL=((.24 * f, 1.47 * f, .02), (.09 * f, 1.7 * f, .05), (-1, 0, 0))),
     'qd_ongtd:ngoighe': lambda: pose(cid, sit=.28, bend=.16, nod=.15, yaw=.15, mouth='smile', aR=((-.24, .6, .12), (-.12, .74, .3), (0, -1, 0)), aL=((.24, .58, .14), (.2, .46, .3), (0, -1, 0)), prop='lyda'),
     # Chị Vy: đứng chờ xe buýt xem điện thoại / bước lên xe buýt / chạy mưa che túi trên đầu
     'qd_vanphong:nhindt': lambda: pose(cid, bend=.04, nod=.42, yaw=.05, mouth='smile', aR=((-.2 * f, .93 * f, .08), (-.05 * f, 1.0 * f, .26 * f), (1, 0, 0)), aL=((.2 * f, .93 * f, .08), (.05 * f, 1.0 * f, .26 * f), (-1, 0, 0)), prop='dt'),
     'qd_vanphong:lenxe': lambda: pose(cid, bend=.12, nod=.05, yaw=-.1, mouth='smile', legs=step, buoc=True, aR=((-.27 * f, 1.18 * f, .18), (-.3 * f, 1.42 * f, .36), (1, 0, 0)), aL=hang(1, f)),
     'qd_vanphong:chemua': lambda: pose(cid, bend=.12, nod=.12, yaw=0, mouth='o', brow=.3, legs=run_, aR=((-.28 * f, 1.42 * f, .1), (-.1 * f, 1.62 * f, .1), (1, 0, 0)), aL=((.28 * f, 1.42 * f, .1), (.1 * f, 1.62 * f, .1), (-1, 0, 0)), prop='tuidau'),
     # Bé Khoa: đi học nắm quai cặp / chạy / ngồi sau xe mẹ
     'qd_hocsinh:dibo': lambda: pose(cid, bend=.02, nod=-.04, yaw=.1, mouth='smile', legs=walk, aR=((-.17, .7, .0), (-.1, .8, .08), (1, 0, .3)), aL=((.17, .7, .0), (.1, .8, .08), (-1, 0, .3))),
     'qd_hocsinh:chay': lambda: pose(cid, bend=.18, nod=-.06, yaw=0, mouth='open', brow=-.6, legs=run_, aR=((-.17, .58, .12), (-.12, .68, .26), (1, 0, .3)), aL=((.17, .56, -.1), (.16, .46, -.06), (-1, 0, 0))),
     'qd_hocsinh:vaybo': lambda: pose(cid, bend=.06, nod=.25, yaw=.15, tilt=.1, mouth='open', brow=-.6, aR=((-.22, .82, .06), (-.24, 1.0, .14), (0, 0, 1)), aL=((.17, .7, .0), (.1, .8, .08), (-1, 0, .3))),
     'qd_hocsinh:ngoisau': lambda: pose(cid, sit=.95, noseat=True, bend=.06, nod=0, yaw=.2, mouth='smile', knee=(.86, .28), ankle=(.58, .24), kx=.2, bike2=True,
                                        aR=((-.18, 1.0, .12), (-.1, 1.0, .28), (0, 0, 1)), aL=((.18, 1.0, .12), (.1, 1.0, .28), (0, 0, 1))),
     # Anh Phúc: đi bộ / ngồi ghế nhựa cà phê / lái xe
     'qd_sinhvien:dibo': lambda: pose(cid, bend=0, nod=-.02, yaw=-.1, mouth='smile', legs=walk, aR=strap(-1, f), aL=swing(1, f, -1)),
     'qd_sinhvien:ngoighe': lambda: pose(cid, sit=.28, bend=.12, nod=.2, yaw=-.1, mouth='smile', aR=((-.26, .62, .14), (-.12, .72, .32), (0, -1, 0)), aL=((.26, .6, .12), (.24, .46, .3), (0, -1, 0)), prop='lyda'),
     'qd_sinhvien:laixe': lambda: pose(cid, bend=.14, nod=-.08, mouth='smile', xe='#2E2E2E', **LAI, **GRIP),
     # Cô Tám vé số: đi rong / chìa vé mời / đứng nghỉ
     'qd_veso:dibo': lambda: pose(cid, bend=.1, nod=.02, yaw=.1, mouth='smile', legs=walk, aL=((.24 * f, .9 * f, .1), (.14 * f, .9 * f, .26), (0, 0, 1)), aR=swing(-1, f, .6), prop='veso'),
     'qd_veso:moive': lambda: pose(cid, bend=.14, nod=.08, yaw=-.15, tilt=.06, mouth='open', brow=-.4, aL=((.24 * f, .9 * f, .1), (.14 * f, .9 * f, .26), (0, 0, 1)), aR=((-.24 * f, 1.06 * f, .26), (-.18 * f, 1.1 * f, .5), (1, 0, .3)), prop='veso+quatve'),
     'qd_veso:dungcho': lambda: pose(cid, bend=.14, nod=.1, yaw=.25, mouth='smile', aL=((.22 * f, .92 * f, .12), (.08 * f, .86 * f, .24), (0, 1, 0)), aR=((-.22 * f, .92 * f, .12), (-.08 * f, .86 * f, .24), (0, 1, 0)), prop='veso'),
     # Anh Đạt: lái xe thùng hàng / dắt xe / đứng gọi khách
     'qd_giaohang:laixe': lambda: pose(cid, bend=.16, nod=-.1, mouth='smile', thung='#3E8E5A', xe='#2E2E2E', **LAI, **GRIP),
     'qd_giaohang:datxe': lambda: pose(cid, bend=.1, nod=.05, yaw=-.15, mouth='smile', legs=walk, datxe=True, xe='#2E2E2E', aL=((.12, 1.08, .2), (-.07, 1.1, .35), (0, -1, 0)), aR=((-.27, 1.1, -.02), (-.36, .95, .02), (0, -1, 0))),
     'qd_giaohang:goidt': lambda: pose(cid, bend=0, nod=-.08, yaw=.2, tilt=-.1, mouth='open', brow=-.3, aR=((-.3 * f, 1.1 * f, .02), (-.17 * f, 1.36 * f, .05), (1, 0, 0)), aL=hang(1, f), prop='dttai'),
     # Chú Bảy: đi bộ / ngồi ăn cơm hộp / lau mồ hôi
     'qd_congnhan:dibo': lambda: pose(cid, bend=.04, nod=0, yaw=.1, mouth='smile', legs=walk, aR=swing(-1, f, 1), aL=swing(1, f, -1)),
     'qd_congnhan:ngoian': lambda: pose(cid, sit=.28, bend=.3, nod=.35, yaw=0, mouth='o', aL=((.22, .58, .14), (.1, .64, .3), (0, 1, 0)), aR=((-.24, .64, .16), (-.08, .76, .3), (0, -1, 0)), prop='hopcom'),
     'qd_congnhan:laumohoi': lambda: pose(cid, bend=-.04, nod=-.12, yaw=.15, tilt=.06, mouth='open', brow=-.5, aR=((-.32 * f, 1.3 * f, .14), (-.08 * f, 1.48 * f, .16), (1, 0, 0)), aL=hips(1, f)),
     # Chị Hoa: lái xe / dắt xe / vẫy con
     'qd_mehoa:laixe': lambda: pose(cid, bend=.1, nod=-.06, mouth='smile', xe='#E8C98A', **LAI, **GRIP),
     'qd_mehoa:datxe': lambda: pose(cid, bend=.1, nod=.05, yaw=-.15, mouth='smile', legs=walk, datxe=True, xe='#E8C98A', aL=((.12, 1.06, .2), (-.07, 1.1, .35), (0, -1, 0)), aR=((-.27, 1.08, -.02), (-.36, .95, .02), (0, -1, 0))),
     'qd_mehoa:vaycon': lambda: pose(cid, bend=0, nod=.05, yaw=.2, tilt=.08, mouth='open', brow=-.5, aR=wave(-1, f), aL=hang(1, f)),
    }
    return D[f'{base}:{dk}']()
def chest_l(f): return ((.22 * f, .95 * f, .14 * f), (.1 * f, 1.0 * f, .3 * f), (0, 1, 0))



# ---- đi xe là đội nón bảo hiểm (Sang duyệt): bản riêng cho người lúc đi bộ không đội nón
def _xe(base, cid, name):
    c = mk(base, cid, name, 'Đi xe máy')
    c['hair'].pop('cap', None)
    c['hair']['nonla'] = False
    c['hair']['helmet'] = c.get('helmet_ride', '#F2F0EA')


_xe('qd_sinhvien', 'qd_sinhvien_xe', 'Anh Phúc (lái xe, nón bảo hiểm)')
_xe('qd_hocsinh', 'qd_hocsinh_xe', 'Bé Khoa (ngồi sau xe mẹ, nón bảo hiểm)')

GOC = list(CH)                     # 8 người gốc
IDS = [k for k in N.CHARS if k.startswith('qd_')]
_D3 = N3.DANG
N3.DANG = DANG
