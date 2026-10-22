"""Hình khối vành phố P1 (toạ độ Godot, mét). Không đụng vùng chơi 96 x 60 m.
Chia lưới: đường cũ chạy tiếp + đường vành mới, mỗi ô lưới ráp nhà quay mặt ra 4 phía.
Nhà vành ở đây là BẢN TẠM để phác thảo; khi vào game thay bằng 'bản xa' của bộ ráp nhà (P2)."""
import math, random
from vp_lib import Chunk, hexc, shade, mix

PLAY = (-48.0, -30.0, 48.0, 30.0)
EXT = (-110.0, -94.0, 110.0, 94.0)
SW = 1.5   # vỉa hè vành

# Đường (x0, z0, x1, z1) mặt nhựa; đặt tên để bàn giao
ROADS = {
    'duong_lon_tay':  (-110, -5, -48, 5),    # qua cầu kênh
    'duong_lon_dong': (48, -5, 103, 5),      # chạy tới ngã ba x=100 thì rẽ
    'doc_bac_x-18':   (-22, -83, -14, -30),
    'doc_bac_x16':    (12, -83, 20, -30),
    'doc_nam_x16':    (12, 30, 20, 83),
    'hem_nam_x-18':   (-19.5, 30, -16.5, 52),  # hẻm 42 nối dài, cổng hẻm khép ở z=31,5
    'ngang_bac_z-54': (-48, -57.5, 103, -50.5),
    'ngang_nam_z54':  (-48, 50.5, 103, 57.5),
    'doc_dong_x72':   (68, -83, 76, 83),
    'vanh_bac_z-83':  (-62, -86, 103, -80),
    'vanh_nam_z83':   (-62, 80, 103, 86),
    'vanh_dong_x100': (97, -86, 103, 86),
    'bo_kenh_tay':    (-67, -94, -62, 94),   # đường dọc bờ tây kênh
    'vanh_tay_x-100': (-103, -94, -97, 94),
}
CANAL = (-62.0, -94.0, -48.6, 94.0)
CANAL_Y = -1.9

PAINT = ['#E2C277', '#EFE2C6', '#A9CFB6', '#E9A98A', '#9FBFCC', '#E2B6B6', '#D8D2C3', '#C5D9A4', '#EBCFA6', '#B8AED3']
ROOF_TON = ['#9C8F82', '#7E9AA3', '#B3765E', '#8F9787']
GLASS = '#3E4A52'
TRIM = '#F4EEE2'
AWN = ['#C8412F', '#2F8F86', '#E0A43A', '#5E8F4E', '#3D6FA8']
SIGN = ['#C8412F', '#2F6FA8', '#E0B33C', '#3E8E5A', '#F2F0EA']


def _cells():
    """Ô lưới vành phố: hình chữ nhật giữa các đường, trừ vùng chơi và kênh."""
    xs = [-110, -103, -97, -67, -62, -48.6, -48, -22, -14, 12, 20, 48, 68, 76, 97, 103, 110]
    zs = [-94, -86, -80, -57.5, -50.5, -30, -5, 5, 30, 50.5, 57.5, 80, 86, 94]
    road_r = list(ROADS.values()) + [CANAL]
    out = []
    for i in range(len(xs) - 1):
        for j in range(len(zs) - 1):
            x0, x1, z0, z1 = xs[i], xs[i + 1], zs[j], zs[j + 1]
            cx, cz = (x0 + x1) / 2, (z0 + z1) / 2
            if PLAY[0] <= cx <= PLAY[2] and PLAY[1] <= cz <= PLAY[3]: continue
            if any(r[0] <= cx <= r[2] and r[1] <= cz <= r[3] for r in road_r): continue
            if x1 - x0 < 3: continue
            out.append([x0, z0, x1, z1])
    # gộp các ô liền nhau theo trục z (cùng x0, x1) nếu không có đường chen giữa
    out.sort(key=lambda r: (r[0], r[1]))
    merged = []
    for r in out:
        if merged and merged[-1][0] == r[0] and merged[-1][2] == r[2] and abs(merged[-1][3] - r[1]) < 1e-6:
            merged[-1][3] = r[3]
        else:
            merged.append(r)
    # ... và theo trục x
    merged.sort(key=lambda r: (r[1], r[0]))
    m2 = []
    for r in merged:
        if m2 and m2[-1][1] == r[1] and m2[-1][3] == r[3] and abs(m2[-1][2] - r[0]) < 1e-6:
            m2[-1][2] = r[2]
        else:
            m2.append(r)
    # hẻm nam x=-18 cắt đôi ô (đã có trong ROADS) -> bỏ phần đè
    return m2


def dist_play(x, z):
    dx = max(PLAY[0] - x, 0, x - PLAY[2]); dz = max(PLAY[1] - z, 0, z - PLAY[3])
    return math.hypot(dx, dz)


SLOT_CC2 = (20.0, -41.5, 44.0, -31.5)   # chung cư cũ thứ hai (P2 dựng), mặt tiền nhìn về nam


def in_slot(x, z):
    s = SLOT_CC2
    return s[0] - .1 <= x <= s[2] + .1 and s[1] - .1 <= z <= s[3] + .1


class Ring:
    def __init__(self, seed=2026):
        self.rng = random.Random(seed)
        self.near = Chunk('VanhGan')      # nhà nhìn thẳng từ vùng chơi
        self.far = Chunk('VanhXa')        # nhà xa, khối + dải cửa
        self.ground = Chunk('MatDuong')
        self.side = Chunk('ViaHe')
        self.green = Chunk('CayVanh')
        self.poles = Chunk('CotDienVanh')
        self.houses = []  # (x, z, w, d, h, hướng) để bàn giao / đếm

    # ---------------------------------------------------------- nhà tạm
    def house(self, ax, az, w, d, facing, near):
        """ax, az: điểm giữa mặt tiền. facing: 'n','s','e','w' (hướng mặt tiền nhìn ra)."""
        r = self.rng
        floors = r.choice([1, 2, 2, 3, 3, 3, 4, 4, 5]) if near else r.choice([2, 3, 3, 4, 5, 6])
        g0, f = 3.4, 3.1
        h = g0 + f * (floors - 1) + .4
        paint = hexc(r.choice(PAINT))
        rot = {'s': 0.0, 'n': math.pi, 'e': math.pi / 2, 'w': -math.pi / 2}[facing]
        # hệ toạ độ cục bộ: u ngang mặt tiền, v vào trong nhà, mặt tiền ở v=0; ra ngoài là -v
        out = {'s': (0, 1), 'n': (0, -1), 'e': (1, 0), 'w': (-1, 0)}[facing]
        tang = (-out[1], out[0]) if facing in 'ns' else (out[1], -out[0])
        tang = (1, 0) if facing in 'ns' else (0, 1)
        def P(u, y, v):
            # v>0 đi vào trong nhà (ngược hướng out)
            return (ax + tang[0] * u - out[0] * v, y, az + tang[1] * u - out[1] * v)
        C = self.near if near else self.far
        self.houses.append(dict(x=round(ax, 2), z=round(az, 2), w=round(w, 2), d=round(d, 2), h=round(h, 1), huong=facing, gan=near))
        hw = w / 2
        def Q(u0, y0, u1, y1, v, col):  # tấm song song mặt tiền, nhìn ra ngoài
            a, b, c, e = P(u0, y0, v), P(u1, y0, v), P(u1, y1, v), P(u0, y1, v)
            C.quad(a, b, c, e, col) if facing in 'sw' else C.quad(b, a, e, c, col)
        # thân: mặt tiền, hai hông, mái phẳng
        Q(-hw, 0, hw, h, 0, paint)
        sidec = shade(paint, .86)
        for u in (-hw, hw):
            a, b, c, e = P(u, 0, 0), P(u, 0, d), P(u, h, d), P(u, h, 0)
            C.quad(a, b, c, e, sidec)

        a, b, c, e = P(-hw, h, 0), P(hw, h, 0), P(hw, h, d), P(-hw, h, d)
        C.quad(a, b, c, e, shade(paint, .8))
        if not near:
            # nhà xa: dải cửa tối mỗi tầng, vài ô sáng ban đêm
            for k in range(floors):
                y0 = (.9 if k == 0 else g0 + f * (k - 1) + .9)
                lit = 1.0 if r.random() < .45 else 0.0
                Q(-hw + .5, y0, hw - .5, y0 + 1.5, -.02, hexc(GLASS if k else '#5A5148', lit * .8))
            if r.random() < .4:
                C.cyl(P(r.uniform(-hw / 2, hw / 2), h, d / 2), .6, 1.4, hexc('#C9CED2'), n=5)
            return
        # ---------- tầng trệt
        kind = r.choice(['cuasat', 'cuasat', 'tiem', 'tiem', 'tiem', 'quan'])
        if kind == 'cuasat':
            Q(-hw + .4, 0, hw - .4, 2.9, -.03, hexc('#9DA3A6'))
            for k in range(3):
                Q(-hw + .4, .7 + k * .8, hw - .4, .76 + k * .8, -.04, hexc('#80878B'))
        else:
            Q(-hw + .4, 0, hw - .4, 2.9, -.03, hexc('#4A3F36', .12))       # lòng tiệm tối, đêm sáng nhẹ
            gc = hexc(r.choice(['#C8412F', '#E0B33C', '#3E8E5A', '#2F6FA8', '#E9A98A']))
            Q(-hw + .7, 0, -hw + .7 + min(1.6, w / 3), 1.1, -.25, gc)       # quầy/kệ hàng ló ra
        sc = hexc(r.choice(SIGN))
        C.box(P(0, 3.25, -.12), (w - .6, .55, .16), sc, rot=-math.atan2(out[0], out[1]) if facing in 'ew' else 0, bottom=False)
        if r.random() < .7:  # mái hiên bạt
            ac = hexc(r.choice(AWN))
            a, b = P(-hw + .1, 2.95, 0), P(hw - .1, 2.95, 0)
            c, e = P(hw - .1, 2.55, -1.1), P(-hw + .1, 2.55, -1.1)
            C.quad(a, b, c, e, ac)
        # ---------- các lầu
        for k in range(1, floors):
            y = g0 + f * (k - 1)
            t = r.choice(['bancong', 'bancong', 'chop', 'logia', 'chuongcop', 'kinh', 'kin'])
            lit = .9 if r.random() < .5 else 0.0
            if t == 'kin':
                Q(-.4, y + 1.6, .4, y + 2.0, -.02, hexc('#7C7A72'))         # ô gió
                continue
            ww = w - 1.2 if t in ('kinh', 'bancong') else w * .55
            Q(-ww / 2, y + .6, ww / 2, y + 2.6, -.02, hexc(GLASS, lit))
            if t == 'chop':
                cc = hexc(r.choice(['#3E7D5A', '#7A5A3A', '#2F6FA8']))
                Q(-ww / 2 - .55, y + .6, -ww / 2, y + 2.6, -.03, cc); Q(ww / 2, y + .6, ww / 2 + .55, y + 2.6, -.03, cc)
            if t in ('bancong', 'logia'):
                C.box(P(0, y + .05, -.5), (w - .2, .14, 1.0), hexc(TRIM), rot=0 if facing in 'ns' else math.pi / 2, bottom=True)
                rc = hexc('#3A3A3A') if t == 'bancong' else paint
                Q(-hw + .1, y + .12, hw - .1, y + 1.05, -1.0, rc)
                if t == 'logia' or r.random() < .4:
                    C.blob(P(-hw + .6, y + .9, -.6), (.4, .35, .4), hexc('#5E8A4E'), n=5, rings=2)
            if t == 'chuongcop':
                a, b, c, e = P(-ww / 2 - .1, y + .5, -.35), P(ww / 2 + .1, y + .5, -.35), P(ww / 2 + .1, y + 2.7, -.35), P(-ww / 2 - .1, y + 2.7, -.35)
                C.quad(a, b, c, e, hexc('#5C6266'))
            if r.random() < .35:  # máy lạnh
                C.box(P(hw - .55, y + .5, -.25), (.75, .5, .3), hexc('#E8E6E0'), rot=0 if facing in 'ns' else math.pi / 2)
        # ---------- mái
        rt = r.choice(['santhuong', 'santhuong', 'ton', 'ngoi', 'tum', 'luoi'])
        if rt == 'santhuong':
            Q(-hw, h, hw, h + .9, -.0, shade(paint, .95))
            C.cyl(P(r.uniform(-hw / 2, hw / 2), h, d * .6), .55, 1.3, hexc('#C9CED2'), n=6)
        elif rt in ('ton', 'ngoi'):
            col = hexc(r.choice(ROOF_TON) if rt == 'ton' else '#B0573C')
            rise = 1.4 if rt == 'ngoi' else .9
            a, b = P(-hw - .1, h, -.3), P(hw + .1, h, -.3)
            c, e = P(hw + .1, h + rise, d / 2), P(-hw - .1, h + rise, d / 2)
            C.quad(a, b, c, e, col)
            a2, b2 = P(-hw - .1, h, d), P(hw + .1, h, d)
            C.quad(b2, a2, e, c, shade(col, .85))
            C.poly([P(-hw, h, 0), P(-hw, h, d), P(-hw, h + rise, d / 2)], sidec)
            C.poly([P(hw, h, d), P(hw, h, 0), P(hw, h + rise, d / 2)], sidec)
        elif rt == 'tum':
            C.box(P(-hw / 3, h + 1.2, d * .6), (min(2.4, w * .5), 2.4, 2.6), paint, rot=0 if facing in 'ns' else math.pi / 2)
        else:  # mái lưới có dây phơi
            for u in (-hw + .2, hw - .2):
                C.box(P(u, h + 1.1, d * .4), (.08, 2.2, .08), hexc('#555555'))
            a, b, c, e = P(-hw, h + 2.2, d * .1), P(hw, h + 2.2, d * .1), P(hw, h + 2.2, d * .7), P(-hw, h + 2.2, d * .7)
            C.quad(a, b, c, e, hexc('#3E6B4A'))
            for k in range(3):
                Q(-hw + .4 + k * w / 3.3, h + 1.0, -hw + .9 + k * w / 3.3, h + 1.7, d * .4, hexc(r.choice(AWN)))

    def fill_cell(self, c):
        x0, z0, x1, z1 = c
        r = self.rng
        # vỉa hè quanh ô
        self.side.box(((x0 + x1) / 2, .075, (z0 + z1) / 2), (x1 - x0, .15, z1 - z0), hexc('#C9C3B3'))
        bx0, bz0, bx1, bz1 = x0 + SW, z0 + SW, x1 - SW, z1 - SW
        if bx1 - bx0 < 3 or bz1 - bz0 < 3: return
        D = min(8.0, (bz1 - bz0) / 2, (bx1 - bx0) / 2)
        sides = [('s', bx0, bx1, bz1, None), ('n', bx0, bx1, bz0, None),
                 ('e', bz0 + D, bz1 - D, bx1, None), ('w', bz0 + D, bz1 - D, bx0, None)]
        for facing, a0, a1, fixed, _ in sides:
            a = a0
            while a < a1 - 1.5:
                w = r.uniform(3.4, 6.0)
                if a1 - a < w + 3.2: w = a1 - a
                mid = a + w / 2
                if facing in 'ns': x, z = mid, fixed
                else: x, z = fixed, mid
                if in_slot(x, z):
                    a += w; continue
                near = dist_play(x, z) < 26
                self.house(x, z, w, D, facing, near)
                a += w
        # lõi ô: khối mái thấp (chỉ thấy từ trên cao)
        ix0, iz0, ix1, iz1 = bx0 + D, bz0 + D, bx1 - D, bz1 - D
        if ix1 - ix0 > 2 and iz1 - iz0 > 2:
            hh = r.uniform(5, 9)
            self.far.box(((ix0 + ix1) / 2, hh / 2, (iz0 + iz1) / 2), (ix1 - ix0, hh, iz1 - iz0), hexc('#B9AE9C'), bottom=False)

    # ---------------------------------------------------------- đường, cây, cột điện
    def roads(self, wet=False):
        g = self.ground
        R = EXT
        # nền nhựa toàn vành (dưới vùng chơi để trống: game có nền riêng)
        rc = hexc('#8F8B80')
        for (a, b, c, d) in [(R[0], R[1], R[2], PLAY[1]), (R[0], PLAY[3], R[2], R[3]), (R[0], PLAY[1], PLAY[0], PLAY[3]), (PLAY[2], PLAY[1], R[2], PLAY[3])]:
            g.quad((a, 0, b), (a, 0, d), (c, 0, d), (c, 0, b), rc)
        lane = hexc('#F2EDE0')
        def dash_x(z, xa, xb):
            x = xa
            while x < xb - 1.8:
                g.quad((x, .02, z - .1), (x, .02, z + .1), (x + 1.8, .02, z + .1), (x + 1.8, .02, z - .1), lane); x += 4.5
        def dash_z(x, za, zb):
            z = za
            while z < zb - 1.8:
                g.quad((x - .1, .02, z), (x - .1, .02, z + 1.8), (x + .1, .02, z + 1.8), (x + .1, .02, z), lane); z += 4.5
        dash_x(0, 48, 97); dash_x(0, -110, -62)
        dash_z(-18, -80, -30); dash_z(16, -80, -30); dash_z(16, 30, 80); dash_z(72, -80, 80)
        dash_x(-54, -48, 97); dash_x(54, -48, 97)
        # vạch qua đường ở các ngã tư mới
        for (cx, cz, ax) in [(-18, -54, 'x'), (16, -54, 'x'), (16, 54, 'x'), (72, 0, 'z'), (72, -54, 'z'), (72, 54, 'z')]:
            for i in range(6):
                if ax == 'x':
                    xx = cx - 3 + i * 1.2; zz = cz + 5.5
                    g.quad((xx - .25, .02, zz - 1.2), (xx - .25, .02, zz + 1.2), (xx + .25, .02, zz + 1.2), (xx + .25, .02, zz - 1.2), lane)
                else:
                    zz = cz - 3 + i * 1.2; xx = cx - 6
                    g.quad((xx - 1.2, .02, zz - .25), (xx - 1.2, .02, zz + .25), (xx + 1.2, .02, zz + .25), (xx + 1.2, .02, zz - .25), lane)
        # ổ vá đường mờ
        for i in range(40):
            x = self.rng.uniform(-100, 100); z = self.rng.choice([self.rng.uniform(-4, 4), self.rng.uniform(-56, -52), self.rng.uniform(52, 56)])
            if dist_play(x, z) < 1: continue
            s = self.rng.uniform(.8, 2.2)
            g.quad((x - s, .015, z - s * .6), (x - s, .015, z + s * .6), (x + s, .015, z + s * .6), (x + s, .015, z - s * .6), hexc('#7E7A70'))

    def canal(self):
        """Kênh phía tây: mặt nước, kè đá hai bờ, lan can bờ đông (mép vùng chơi), cầu trên đường lớn."""
        g = self.ground; x0, z0, x1, z1 = CANAL
        stone = hexc('#A39A88'); dark = hexc('#7D7466')
        g.quad((x0, CANAL_Y - .6, z0), (x0, CANAL_Y - .6, z1), (x1, CANAL_Y - .6, z1), (x1, CANAL_Y - .6, z0), hexc('#4E6B5E'))
        for x, s in ((x0, 1), (x1, -1)):
            g.quad((x, CANAL_Y - .6, z0), (x, 0, z0), (x, 0, z1), (x, CANAL_Y - .6, z1), stone) if s > 0 else \
                g.quad((x, CANAL_Y - .6, z1), (x, 0, z1), (x, 0, z0), (x, CANAL_Y - .6, z0), stone)
            g.quad((x, CANAL_Y + .3, z0), (x, CANAL_Y + .3, z1), (x, CANAL_Y - .6, z1), (x, CANAL_Y - .6, z0), dark)
        # dải đất bờ đông (giữa đường biên vùng chơi và mép kè)
        g.quad((-48.6, 0, -94), (-48.6, 0, 94), (-48, 0, 94), (-48, 0, -94), hexc('#C9C3B3'))
        # lan can bờ đông: trụ + 2 thanh, mỗi 2,5 m một trụ
        P = self.poles
        for zz in range(-92, 93, 3):
            if -6.5 < zz < 6.5: continue
            P.box((-48.35, .5, zz), (.12, 1.0, .12), hexc('#3F5A55'), sides=(1, 1, 1, 1))
        for (za, zb) in ((-94, -6.2), (6.2, 94)):
            for y in (.45, .95):
                P.box((-48.35, y, (za + zb) / 2), (.06, .06, zb - za), hexc('#3F5A55'))
        # lan can bờ tây
        for (za, zb) in ((-94, -6.2), (6.2, 94)):
            P.box((-62.25, .45, (za + zb) / 2), (.3, .9, zb - za), hexc('#B8AE9C'))
        # cầu: mặt cầu hơi vồng, lan can, 4 cột đèn
        deck = hexc('#9B968C')
        xs = [-48.6, -52, -55.3, -58.6, -62]
        ys = [0, .35, .45, .35, 0]
        for i in range(4):
            g.quad((xs[i], ys[i] + .01, -6), (xs[i], ys[i] + .01, 6), (xs[i + 1], ys[i + 1] + .01, 6), (xs[i + 1], ys[i + 1] + .01, -6), deck)
            for zz in (-6, 6):
                s = 1 if zz > 0 else -1
                a, b = (xs[i], ys[i], zz), (xs[i + 1], ys[i + 1], zz)
                c, d = (xs[i + 1], ys[i + 1] + 1.0, zz), (xs[i], ys[i] + 1.0, zz)
                col = hexc('#D9D2C2')
                g.quad(a, b, c, d, col)
                g.quad((xs[i], ys[i] - .9, zz), (xs[i + 1], ys[i + 1] - .9, zz), b, a, hexc('#8C8577'))
        g.quad((-62, CANAL_Y, -6), (-48.6, CANAL_Y, -6), (-48.6, CANAL_Y, 6), (-62, CANAL_Y, 6), hexc('#5B5A55'))  # bóng gầm cầu
        for (x, z) in [(-49.2, -6.4), (-49.2, 6.4), (-61.4, -6.4), (-61.4, 6.4)]:
            self.lamp(x, z)

    def lamp(self, x, z, y0=0.0):
        P = self.poles
        P.cyl((x, y0, z), .09, 4.6, hexc('#3F5A55'), n=5, top=False)
        P.box((x, y0 + 4.7, z), (.35, .3, .35), hexc('#FFF2C8', 1.0), bottom=True)

    def trees_poles(self):
        r = self.rng; G = self.green; P = self.poles
        def tree(x, z, big=False):
            h = r.uniform(7, 11) if big else r.uniform(5, 7)
            G.cyl((x, 0, z), .22 if big else .16, h * .62, hexc('#6E5A45'), n=5, top=False)
            G.blob((x, h * .72, z), (r.uniform(2.4, 3.4), h * .28, r.uniform(2.4, 3.4)), hexc(r.choice(['#5E8A4E', '#6E9A55', '#557F48'])), n=6, rings=3)
        # hàng cây bờ kênh tây, dọc đường lớn, dọc hai đường bắc
        for z in range(-90, 91, 11):
            if abs(z) > 8: tree(-65.8 + r.uniform(-.2, .2), z + r.uniform(-1, 1), True)
        for x in list(range(-104, -66, 12)) + list(range(53, 96, 12)):
            tree(x, -6.2, x > 0); tree(x + 5, 6.2, x > 0)
        for z in range(-78, -33, 13):
            tree(-23, z); tree(-13, z + 6); tree(11, z + 3); tree(21, z - 2)
        for z in range(36, 78, 13):
            tree(11, z); tree(21, z + 6)
        for z in range(-78, 79, 14):
            if abs(z) > 8 and abs(abs(z) - 54) > 5: tree(67.2, z); tree(76.8, z + 5)
        # cột điện + dây dọc vài tuyến (vành gần)
        def pole_line(pts):
            tops = []
            for (x, z) in pts:
                P.box((x, 4, z), (.24, 8, .24), hexc('#8E8A80'))
                P.box((x, 7.6, z), (1.4, .12, .12), hexc('#6E6A62'))
                tops.append((x, z))
            for (a, b) in zip(tops, tops[1:]):
                for off, yy in ((-.6, 7.65), (0, 7.4), (.6, 7.65)):
                    self.wire((a[0] + off * (a[1] != b[1]), yy, a[1] + off * (a[0] != b[0])), (b[0] + off * (a[1] != b[1]), yy, b[1] + off * (a[0] != b[0])))
        pole_line([(x, -6.6) for x in range(52, 100, 15)])
        pole_line([(x, 6.6) for x in range(-106, -66, 14)])
        pole_line([(-13.3, z) for z in range(-34, -82, -15)])
        pole_line([(20.7, z) for z in range(-34, -82, -15)])
        pole_line([(11.3, z) for z in range(34, 82, 15)])

    def wire(self, a, b, sag=.6, n=4):
        pts = []
        for i in range(n + 1):
            t = i / n
            pts.append((a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t - sag * 4 * t * (1 - t), a[2] + (b[2] - a[2]) * t))
        col = hexc('#2A2A2A')
        for p, q in zip(pts, pts[1:]):
            self.poles.quad(p, q, (q[0], q[1] + .04, q[2]), (p[0], p[1] + .04, p[2]), col)


    def build_all(self):
        self.roads()
        self.canal()
        for c in _cells():
            self.fill_cell(c)
        self.trees_poles()
        # khối giữ chỗ chung cư cũ thứ hai (P2 dựng model thật)
        s = SLOT_CC2
        self.near.box(((s[0] + s[2]) / 2, 9, (s[1] + s[3]) / 2), (s[2] - s[0], 18, s[3] - s[1]), hexc('#E6DCC6'))
        for k in range(5):
            y = 3.6 + k * 3.1
            for i in range(8):
                xx = s[0] + 1.6 + i * 2.95
                self.near.quad((xx, y, s[3] + .03), (xx + 1.8, y, s[3] + .03), (xx + 1.8, y + 1.9, s[3] + .03), (xx, y + 1.9, s[3] + .03), hexc(GLASS, .9 if (i + k) % 3 else 0))
            self.near.box(((s[0] + s[2]) / 2, y - .1, s[3] + .55), (s[2] - s[0] - .4, .15, 1.1), hexc('#F4EEE2'), bottom=True)
        return self
