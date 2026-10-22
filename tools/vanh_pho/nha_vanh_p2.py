"""Nhà vành phố bản xa theo bộ ráp nhà P2 (thay nhà tạm của P1 trong vanh_pho.glb).
Ô lưới, mặt tiền, vỉa hè như P1 (vanh.py, vp_lib.py chép từ gói P1). Mỗi căn chọn kiểu trệt / lầu / mái / màu sơn của
bộ ráp P2 (bo_rap.py: TRET, LAU, MAI, SON) và vẽ như bo_rap.nha_xa nhưng chỉ các mặt nhìn thấy được:
  - dãy gần (cách vùng chơi < 26 m): 40–80 tam giác: mặt tiền, hông, mái, ô trệt + bảng hiệu + bạt, mỗi lầu gờ sàn +
    cửa (ban công / chuồng cọp / cửa chớp / lô gia / kính lùa / tường kín), mái theo 5 kiểu.
  - dãy sau: ~16–24 tam giác: mặt tiền, nóc, dải cửa mỗi tầng, mái tôn/ngói thì một mặt dốc.
Màu đỉnh A = ô kính sáng đèn ban đêm (như P1). Chừa ô chung cư Ngọc Lan lô C và ô hai nhà mốc phía nam (biệt thự,
mẫu giáo) để game đặt model thật.
Dùng (cần bpy): python3 nha_vanh_p2.py <ra_thư_mục>   -> nha_vanh_p2.glb (VanhGan, VanhXa) + nha_vanh.json"""
import sys, os, math, random, json
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import bpy
from vp_lib import hexc, shade, mat_vc
import vanh

OUT = sys.argv[1]
os.makedirs(OUT, exist_ok=True)

# Bộ ráp P2 (bo_rap.py): 10 màu sơn, viền chung, kiểu trệt có trọng số như scripts/nha_rap.gd
SON = ['#E2C07E', '#77AD9C', '#DB957A', '#B6CFC8', '#EEDDB2', '#CFA0BA', '#9FBEDD', '#DCD27A', '#A9C68A', '#D6D0C2']
TRIM = '#F1ECE2'
TRET = ['nha_o'] * 4 + ['tap_hoa', 'quan_pho', 'sua_dt', 'tiem_may', 'tiem_thuoc', 'gui_xe', 'hot_toc']
# màu bảng hiệu chính của 21 bảng P2 theo kiểu tiệm (bang_hieu.py)
BANG = dict(tap_hoa=['#B8322A', '#2F6B45', '#F2D27A'], quan_pho=['#F2B33D', '#9C6A40', '#C8312A'],
            sua_dt=['#1F5FB0', '#F2C14E', '#8E9598'], tiem_may=['#D2368A', '#F7EEDC', '#9C6A40'],
            tiem_thuoc=['#F4F4F0', '#2E7D4F', '#BFD8DE'], gui_xe=['#2F6FA8', '#F1ECE2', '#F2C14E'],
            hot_toc=['#5E3E22', '#B06AB3', '#2457A0'])
BAT = ['#3F8A5C', '#C8412F', '#2F8F86', '#E0A43A', '#3D6FA8']
LAU = ['ban_cong', 'cua_chop', 'lo_gia', 'chuong_cop', 'kinh_lua', 'tuong_kin']
MAI = ['san_thuong'] * 3 + ['tum'] * 2 + ['ton'] * 2 + ['luoi'] * 2 + ['ngoi']
TON = ['#7E9AA3', '#B3765E', '#5E8FB8', '#9C8F82']
NGOI = '#B0573C'
GLASS = '#3A4644'
SAT = '#3A3A3A'
G0, F = 3.4, 3.1

# Ô chừa cho nhà mốc: chung cư lô C (P1 đã chừa) + biệt thự và mẫu giáo đối diện tiệm xe (mặt tiền z = 31,5 nhìn bắc)
MOC = [vanh.SLOT_CC2, (21.5, 31.5, 46.6, 45.0)]


def in_slot(x, z):
    return any(s[0] - .1 <= x <= s[2] + .1 and s[1] - .1 <= z <= s[3] + .1 for s in MOC)


vanh.in_slot = in_slot


class RingP2(vanh.Ring):
    def house(self, ax, az, w, d, facing, near):
        r = self.rng
        floors = r.choice([1, 2, 2, 3, 3, 3, 4, 4, 5]) if near else r.choice([2, 3, 3, 4, 5, 6])
        own = random.Random(hash((round(ax, 1), round(az, 1))) & 0xffffffff)   # chi tiết căn: không lệch chuỗi số của ô
        n = floors - 1
        h = G0 + F * n
        paint = hexc(own.choice(SON))
        tret = own.choice(TRET)
        lau = []
        for i in range(n):
            lau.append(lau[-1] if lau and own.random() < .45 else own.choice(LAU))
        mai = own.choice(MAI)
        self.houses.append(dict(x=round(ax, 2), z=round(az, 2), w=round(w, 2), d=round(d, 2), h=round(h + (.9 if mai in ('san_thuong', 'tum', 'luoi') else 0), 1),
                                huong=facing, gan=near, tret=tret, lau=lau, mai=mai))
        out = {'s': (0, 1), 'n': (0, -1), 'e': (1, 0), 'w': (-1, 0)}[facing]
        tang = (1, 0) if facing in 'ns' else (0, 1)

        def P(u, y, v):   # u ngang mặt tiền, v vào trong nhà
            return (ax + tang[0] * u - out[0] * v, y, az + tang[1] * u - out[1] * v)
        C = self.near if near else self.far
        flip = facing not in 'sw'

        def Q(u0, y0, u1, y1, v, col):   # tấm song song mặt tiền, nhìn ra ngoài
            a, b, c, e = P(u0, y0, v), P(u1, y0, v), P(u1, y1, v), P(u0, y1, v)
            C.quad(b, a, e, c, col) if flip else C.quad(a, b, c, e, col)

        def T(u0, u1, y, v0, v1, col):   # tấm nằm ngang (mặt trên)
            a, b, c, e = P(u0, y, v0), P(u1, y, v0), P(u1, y, v1), P(u0, y, v1)
            C.quad(e, c, b, a, col) if flip else C.quad(a, b, c, e, col)
        hw = w / 2
        # thân: mặt tiền + nóc (+ hai hông ở dãy gần)
        Q(-hw, 0, hw, h, 0, paint)
        T(-hw, hw, h, 0, d, shade(paint, .8))
        if near:
            for u in (-hw, hw):
                a, b, c, e = P(u, 0, 0), P(u, 0, d), P(u, h, d), P(u, h, 0)
                C.quad(a, b, c, e, shade(paint, .86))
        if not near:
            # dãy sau: một dải cửa tối mỗi tầng (vài ô sáng ban đêm), mái dốc một mặt
            for k in range(floors):
                y0 = .5 if k == 0 else G0 + F * (k - 1) + .7
                Q(-hw + .4, y0, hw - .4, y0 + (2.2 if k == 0 else 1.5), -.02, hexc(GLASS if k else '#4A4038', (.8 if own.random() < .45 else 0) if k else .1))
            if mai in ('ton', 'ngoi'):
                rise = 1.3 if mai == 'ngoi' else .6
                a, b = P(-hw, h, 0), P(hw, h, 0)
                c, e = P(hw, h + rise, d / 2), P(-hw, h + rise, d / 2)
                C.quad(b, a, e, c, hexc(NGOI if mai == 'ngoi' else own.choice(TON))) if flip else C.quad(a, b, c, e, hexc(NGOI if mai == 'ngoi' else own.choice(TON)))
            else:
                Q(-hw, h, hw, h + .9, 0, shade(paint, .95))   # tường lửng sân thượng
            return
        # ---------- trệt
        if tret == 'nha_o':
            Q(-hw + .35, 0, hw - .35, 2.9, -.03, hexc('#8E9496'))                       # cửa sắt kéo
        else:
            Q(-hw + .35, 0, hw - .35, 2.9, -.03, hexc('#4A3F36', .12))                  # lòng tiệm tối, đêm sáng nhẹ
            Q(-hw + .15, 2.98, hw - .15, 3.36, -.12, hexc(own.choice(BANG[tret])))       # bảng hiệu trên mái hiên
            if own.random() < .6:
                bat = hexc(own.choice(BAT))
                a, b = P(-hw + .1, 2.95, 0), P(hw - .1, 2.95, 0)
                c, e = P(hw - .1, 2.6, -1.0), P(-hw + .1, 2.6, -1.0)
                C.quad(b, a, e, c, bat) if flip else C.quad(a, b, c, e, bat)
        # ---------- lầu
        for i, k in enumerate(lau):
            y = G0 + F * i
            Q(-hw - .02, y - .08, hw + .02, y + .1, -.08, hexc(TRIM))                     # gờ sàn
            lit = .9 if own.random() < .5 else 0.0
            if k == 'tuong_kin':
                Q(-.35, y + 1.7, .35, y + 2.1, -.02, hexc('#7C7A72'))                   # ô gió
                continue
            ww = w - 1.2 if k in ('kinh_lua', 'ban_cong') else w * .55
            Q(-ww / 2, y + .5, ww / 2, y + 2.5, -.02, hexc(GLASS if k != 'kinh_lua' else '#8FB3BC', lit))
            if k == 'cua_chop':
                cc = hexc(own.choice(['#3E7D5A', '#7A5A3A', '#2F6FA8']))
                Q(-ww / 2 - .5, y + .5, -ww / 2, y + 2.5, -.03, cc); Q(ww / 2, y + .5, ww / 2 + .5, y + 2.5, -.03, cc)
            elif k in ('ban_cong', 'kinh_lua'):
                T(-hw + .1, hw - .1, y + .1, -.9, 0, hexc(TRIM))                          # sàn ban công
                Q(-hw + .1, y + .1, hw - .1, y + 1.0, -.9, hexc(SAT if k == 'ban_cong' else '#BFD8DE'))
            elif k == 'chuong_cop':
                Q(-ww / 2 - .1, y + .4, ww / 2 + .1, y + 2.6, -.4, hexc('#5C6266'))
            elif k == 'lo_gia':
                Q(-hw + .3, y + .1, hw - .3, y + .9, -.03, paint)                         # lan can xây
        # ---------- mái
        if mai in ('ton', 'ngoi'):
            col = hexc(NGOI if mai == 'ngoi' else own.choice(TON))
            rise = 1.7 if mai == 'ngoi' else .7
            a, b = P(-hw - .1, h, -.3), P(hw + .1, h, -.3)
            c, e = P(hw + .1, h + rise, d / 2), P(-hw - .1, h + rise, d / 2)
            C.quad(b, a, e, c, col) if flip else C.quad(a, b, c, e, col)
            for u in (-hw, hw):
                C.poly([P(u, h, 0), P(u, h, d), P(u, h + rise, d / 2)], shade(paint, .86))
        else:
            Q(-hw, h, hw, h + .9, 0, shade(paint, .95))                                  # tường lửng
            if mai == 'tum':
                C.box(P(hw / 3, h + 1.25, d * .65), (min(2.4, w * .5), 2.5, 2.6), paint, rot=0 if facing in 'ns' else math.pi / 2, sides=(1, 1, 1, 1))
            elif mai == 'san_thuong':
                C.cyl(P(hw * .4, h, d * .7), .45, 1.3, hexc('#C9CED2'), n=5)
            else:   # mái lưới có dây phơi
                T(-hw + .2, hw - .2, h + 2.4, d * .1, d * .7, hexc('#3E6B4A'))

    def build_all(self):
        for c in vanh._cells():
            self.fill_cell(c)
        return self


bpy.ops.wm.read_factory_settings(use_empty=True)
ring = RingP2().build_all()
coll = bpy.context.scene.collection
mat = mat_vc('VanhPho')
objs = [ring.near.build(mat, coll), ring.far.build(mat, coll)]
near = [h for h in ring.houses if h['gan']]
far = [h for h in ring.houses if not h['gan']]
print('nha vanh', len(ring.houses), 'gan', len(near), 'tam giac gan', ring.near.tris, '(%.0f/căn)' % (ring.near.tris / max(1, len(near))),
      'xa + loi o', ring.far.tris, '(%.0f/căn)' % (ring.far.tris / max(1, len(far))))
for o in coll.objects: o.select_set(o in objs)
bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, 'nha_vanh_p2.glb'), use_selection=True, export_format='GLB',
                          export_vertex_color='ACTIVE', export_materials='EXPORT', export_apply=True)
json.dump(ring.houses, open(os.path.join(OUT, 'nha_vanh.json'), 'w'), ensure_ascii=False)
