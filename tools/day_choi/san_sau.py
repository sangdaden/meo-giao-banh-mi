"""B1 · Sân sau lò bánh (màn dạy chơi): 6 món mới phong cách D, dựng bằng kit.py của P4/G1 (Blender 5.2, bpy).
Toạ độ Blender: x dọc mặt chính, -Y là phía trước (phía sân, camera nhìn vào), Z lên, mét thật. Gốc giữa đáy.
Mỗi hàm dựng một món ở gốc, trả về group. st = trạng thái phụ (None = trạng thái chính).
o['ngu_canh'] = 1: chỉ làm bối cảnh trong ảnh, không vào bản game."""
import math, random
import numpy as np
import bpy
import kit
from kit import M, C, group, at, box, boxab, cyl, ball, curve, sag, mesh_obj, corrugated

R = random.Random

PLASTER = '#D2B08F'    # vữa trát cũ mặt sau, ấm hơn mặt tiền
PLASTER2 = '#C49E7C'
BRICK = '#B4553A'
BRICK2 = '#9A4430'
PLINTH = '#8E7A66'
DOOR = '#2E7C80'       # xanh cửa sắt Sài Gòn, cùng màu túi bánh
DOOR2 = '#246567'
WOOD = '#8A5A30'
WOOD2 = '#B07C46'
CONCRETE = '#B9B3A6'
MOSS = '#7E8F55'


def moss(x, w, y=-.01, seed=1):
    """Rêu chân tường: vài mảng dẹt mềm, không thành vệt thẳng."""
    rnd = R(seed)
    for i in range(int(w / .12)):
        ball(rnd.uniform(.05, .09), (x - w / 2 + i * .12 + rnd.uniform(-.03, .03), y, rnd.uniform(.0, .08)), M(MOSS if i % 2 else '#6E8048', .95), scale=(1.3, .25, .8), sub=1)


def ctx(o):
    o['ngu_canh'] = 1; return o


def brick_patch(x0, z0, cols, rows, y, seed=1):
    """Mảng gạch lộ ra chỗ vữa bong: gạch 0,2 × 0,07 m, so le."""
    rnd = R(seed)
    for r in range(rows):
        off = .1 if r % 2 else 0
        for c in range(cols):
            if rnd.random() < .18: continue
            x = x0 + off + c * .21
            box((.19, .03, .06), (x, y - .012, z0 + r * .075), M(BRICK if rnd.random() < .6 else BRICK2, .85), .004)


# =============================================================== MẶT SAU LÒ BÁNH

def mat_sau_lo(st=None):
    """Mặt sau Lò bánh Cô Ba, dài 8 m, tường cao 3,6 m: vữa trát cũ bong vài mảng lộ gạch, chân tường sẫm 0,4 m.
    Cửa sau 2 cánh sắt xanh 1,2 × 2,1 m (một cánh mở hé), 2 bậc xi măng 0,15 m, mái tôn nhỏ che cửa, bóng đèn tròn.
    Cửa sổ bếp 1,2 × 1,0 m bậu cao 1,1 m: song sắt 5 thanh, cánh gỗ mở ra, bên trong ánh lửa lò; bậu 0,18 m là chỗ Cô Ba đưa bánh.
    Ống khói gạch 0,6 × 0,6 m nhô lên tới 5,2 m, miệng ám khói. Ống nước mưa, móc treo chổi.
    st='toi' = bản đèn cửa sau và lửa lò sáng (5 giờ 40 sáng còn tối)."""
    g = group('mat_sau_lo')
    glow = .9 if st == 'toi' else .5
    with at(g):
        wall = M(PLASTER, .92)
        # tường chừa lỗ cửa và cửa sổ: ghép từ các tấm
        y0, y1 = 0, .25
        boxab((-4, y0, 0), (-3.2, y1, 3.6), wall, .01)               # trái cửa sổ
        boxab((-2.0, y0, 0), (-.1, y1, 3.6), wall, .01)              # giữa cửa sổ và cửa
        boxab((1.1, y0, 0), (4, y1, 3.6), wall, .01)                 # phải cửa
        boxab((-3.2, y0, 0), (-2.0, y1, 1.1), wall, .01)             # dưới cửa sổ
        boxab((-3.2, y0, 2.1), (-2.0, y1, 3.6), wall, .01)           # trên cửa sổ
        boxab((-.1, y0, 2.1), (1.1, y1, 3.6), wall, .01)             # trên cửa
        boxab((-4.02, -.02, 3.6), (4.02, .27, 3.75), M(PLASTER2, .9), .015)   # gờ đầu tường
        # chân tường sẫm + rêu
        for a, b in ((-4, -3.2), (-3.2, -2.0), (-2.0, -.1), (1.1, 4)):
            boxab((a, -.015, 0), (b, y0, .4), M(PLINTH, .95), .005)
        for i, x in enumerate((-3.6, -1.4, 2.0, 3.4)):
            moss(x, .5 + .2 * (i % 2), seed=i)
        # mảng vữa bong lộ gạch
        brick_patch(-3.9, 2.6, 3, 4, 0, seed=2)
        brick_patch(1.6, .7, 4, 3, 0, seed=5)
        brick_patch(2.9, 2.9, 3, 5, 0, seed=7)
        # ---- cửa sau
        frm = M(DOOR2, .5, .4)
        boxab((-.16, -.04, 0), (-.1, .06, 2.16), frm, .005); boxab((1.1, -.04, 0), (1.16, .06, 2.16), frm, .005)
        boxab((-.16, -.04, 2.1), (1.16, .06, 2.16), frm, .005)
        leaf = M(DOOR, .45, .35, coat=.2)
        gl = group('canh_trai', (-.1, .02, 0))
        with at(gl):
            boxab((0, -.02, .02), (.6, .02, 2.08), leaf, .008)
            for z in (.5, 1.0, 1.5): boxab((.04, -.035, z), (.56, -.02, z + .04), frm, .004)
            box((.03, .05, .12), (.52, -.04, 1.05), M(C['steel'], .3, .9), .005)
        gr = group('canh_phai', (1.1, .02, 0), rot=math.radians(-35))   # mở hé ra sân
        with at(gr):
            boxab((-.6, -.02, .02), (0, .02, 2.08), leaf, .008)
            for z in (.5, 1.0, 1.5): boxab((-.56, -.035, z), (-.04, -.02, z + .04), frm, .004)
        boxab((-.1, .06, 0), (1.1, .25, 2.1), M('#4A3A2E', .95), 0)                 # trong nhà tối
        # bậc xi măng
        boxab((-.35, -.35, 0), (1.35, 0, .15), M(CONCRETE, .9), .02)
        boxab((-.25, -.7, 0), (1.25, -.35, .075), M(CONCRETE, .9), .02)
        boxab((-.35, -.36, .148), (1.35, -.33, .152), M(C['concrete2'], .9), 0)
        # mái tôn che cửa + đèn
        for x in (-.3, 1.3): boxab((x - .025, -.65, 2.32), (x + .025, 0, 2.36), M(C['iron'], .5, .6), .004)
        corrugated(1.9, .75, M(C['ton_rust'], .55, .35), (.5, -.35, 2.42), rot=(math.radians(-10), 0, 0))
        cyl(.012, .25, (.5, -.05, 2.24), M(C['dark'], .6), bv=0, n=6)
        ball(.07, (.5, -.1, 2.12), M('#FFE6A8', .2, emit=4.0 * glow), sub=2)
        # ---- cửa sổ bếp
        wx, wz0, wz1 = -2.6, 1.1, 2.1
        boxab((-3.25, -.06, 1.02), (-1.95, .2, 1.1), M(CONCRETE, .85), .015)       # bậu đưa bánh
        boxab((-3.2, .05, 1.1), (-2.0, .25, 2.1), M('#3A2A20', .95), 0)             # trong tối
        boxab((-3.0, .2, 1.1), (-2.2, .24, 1.55), M('#E8743A', .4, emit=2.2 * glow), 0)   # ánh lửa lò
        boxab((-3.2, -.03, 2.06), (-2.0, .03, 2.12), M(WOOD, .8), .005)
        for i in range(5):
            x = -3.1 + i * .25
            cyl(.012, 1.0, (x, -.01, 1.6), M(C['iron'], .5, .6), n=8, bv=0)
        for z in (1.35, 1.85): boxab((-3.2, -.025, z), (-2.0, .005, z + .025), M(C['iron'], .5, .6), .003)
        for sx, x0 in ((-1, -3.2), (1, -2.0)):                                     # cánh gỗ mở bật ra hai bên
            sh = group('chop', (x0, -.02, 1.1), rot=math.radians(-100 * sx))
            with at(sh):
                boxab((0 if sx > 0 else -.6, -.02, 0), (.6 if sx > 0 else 0, .02, 1.0), M('#5E8F6A', .6, coat=.15), .008)
                for z in (.15, .35, .55, .75): boxab((.05 if sx > 0 else -.55, -.035, z), (.55 if sx > 0 else -.05, -.02, z + .1), M('#4F7D5C', .6), .004)
        # ---- ống khói
        boxab((2.7, -.05, 3.0), (3.3, .55, 5.2), M(BRICK, .85), .02)
        for k in range(10):
            boxab((2.69, -.06, 3.05 + k * .22), (3.31, -.05, 3.07 + k * .22), M(BRICK2, .9), 0)
        boxab((2.62, -.12, 5.2), (3.38, .62, 5.3), M(CONCRETE, .9), .02)
        boxab((2.75, .0, 5.3), (3.25, .5, 5.36), M('#2A2522', .95), .01)              # miệng ám khói
        # ống nước mưa + móc chổi
        cyl(.045, 3.7, (3.8, -.08, 1.85), M('#8FA3A0', .5, .2), n=10, bv=0)
        for z in (.8, 2.0, 3.2): boxab((3.74, -.14, z), (3.86, -.02, z + .03), M(C['iron'], .5, .6), .003)
        cyl(.012, .1, (1.8, -.05, 1.6), M(C['iron'], .5, .6), rot=(math.pi / 2, 0, 0), n=6, bv=0)
        cyl(.018, 1.2, (1.8, -.12, 1.0), M(WOOD2, .8), rot=(.08, 0, 0), n=8, bv=0)   # cán chổi chà
        cyl(.09, .32, (1.8, -.17, .3), M('#C9A86A', .95), r2=.05, n=10, bv=0)        # bông chổi
    return g


# =============================================================== KHO CỦI

def kho_cui(st=None):
    """Kho củi mái tôn, mặt trước rộng 2,5 m (nhìn ra sân), sâu 4 m. 4 cột gỗ, vách ván 3 mặt, mặt trước để trống.
    Mái tôn sét dốc ra sau: mép trước 1,8 m (mặt Bơ đứng), mép sau 2,1 m, chìa 0,15 m.
    Bên trong củi chẻ chất 3 lớp tới 1,2 m, rìu gỗ dựng góc. Bản game: hộp va chạm nóc 1,8 m.
    Rổ tre trên mái chỉ có trong ảnh (dùng ro_tre có sẵn trong bộ đồ bếp)."""
    g = group('kho_cui')
    W, D = 2.5, 4.0
    with at(g):
        post = M(WOOD, .85); plank = M('#9C7048', .9); plank2 = M('#87603D', .9)
        for x in (-W / 2 + .06, W / 2 - .06):
            for y, h in ((-D / 2 + .06, 1.76), (D / 2 - .06, 1.96)):
                boxab((x - .06, y - .06, 0), (x + .06, y + .06, h), post, .01)
        # vách ván 2 bên + sau
        for i in range(9):
            z = .05 + i * .2
            for sx in (-1, 1):
                boxab((sx * W / 2 - .03, -D / 2 + .1, z), (sx * W / 2 + .01, D / 2 - .1, z + .18), plank if i % 2 else plank2, .006)
            if z < 1.9: boxab((-W / 2 + .1, D / 2 - .03, z), (W / 2 - .1, D / 2 + .01, z + .18), plank2 if i % 2 else plank, .006)
        # xà đỡ mái
        for y, z in ((-D / 2 + .06, 1.76), (D / 2 - .06, 1.96)):
            boxab((-W / 2, y - .05, z), (W / 2, y + .05, z + .08), post, .008)
        # mái tôn sét
        slope = math.atan2(.3, D)
        corrugated(W + .3, D + .35, M(C['ton_rust'], .55, .35), (0, 0, 1.98), rot=(-slope, 0, 0))
        boxab((-W / 2 - .15, -D / 2 - .19, 1.8), (W / 2 + .15, -D / 2 - .15, 1.86), M('#7E5636', .7, .3), .004)   # nẹp mép trước
        # củi chẻ chất bên trong
        rnd = R(4)
        for layer in range(3):
            for row in range(7):
                for col in range(6):
                    if rnd.random() < .04: continue
                    x = -W / 2 + .25 + col * .34 + rnd.uniform(-.03, .03)
                    z = .12 + row * .17 + layer * .0
                    y = -D / 2 + .7 + layer * 1.0
                    cyl(.075 + rnd.uniform(-.015, .01), .9, (x, y + .45, z), M('#A97A4E' if rnd.random() < .5 else '#93653C', .9),
                        rot=(math.pi / 2, 0, rnd.uniform(-.05, .05)), n=6, bv=.006)
            # mặt gỗ sáng ở đầu khúc củi
        for row in range(7):
            for col in range(6):
                x = -W / 2 + .25 + col * .34; z = .12 + row * .17
                cyl(.065, .01, (x, -D / 2 + .69, z), M('#E2C08E', .85), rot=(math.pi / 2, 0, 0), n=6, bv=0)
        # rìu dựng góc
        cyl(.02, .8, (W / 2 - .3, -D / 2 + .35, .4), M(WOOD2, .8), rot=(.15, 0, 0), n=8, bv=0)
        box((.16, .03, .1), (W / 2 - .3, -D / 2 + .41, .8), M(C['steel'], .35, .8), .005)
        # rổ tre trên mái (ảnh)
        ctx(cyl(.24, .12, (.35, .2, 2.0), M('#C9A25A', .9), r2=.3, n=16, bv=.01))
    return g


# =============================================================== CỔNG SAU + TƯỜNG RÀO

def cong_sau(st=None):
    """Cổng sắt nhỏ ra hẻm, lọt lòng 1,4 × 1,7 m giữa 2 trụ gạch 0,35 m cao 2,1 m có mũ trụ.
    Cánh cổng: khung sắt sơn xanh đậm, song đứng 10 cm, nửa trên hoa văn quả trám, then cài + ổ khóa treo.
    Ô thư nhỏ gắn trên trụ phải. st='mo' = cánh mở vào sân 70° (lúc Chú Tư đứng chờ)."""
    g = group('cong_sau')
    with at(g):
        for sx in (-1, 1):
            x = sx * (.7 + .175)
            boxab((x - .175, -.175, 0), (x + .175, .175, 2.1), M(PLASTER, .9), .015)
            boxab((x - .21, -.21, 2.1), (x + .21, .21, 2.2), M(CONCRETE, .85), .02)
            box((.28, .28, .1), (x, 0, 2.27), M(CONCRETE, .85), .03)
            boxab((x - .176, -.176, 0), (x + .176, .176, .3), M(PLINTH, .95), .004)
        iron = M('#2C4A4A', .45, .55)
        ang = math.radians(70) if st == 'mo' else 0
        gg = group('canh', (-.7, 0, 0), rot=-ang)
        with at(gg):
            for z in (.08, .85, 1.72): boxab((0, -.025, z - .025), (1.4, .025, z + .025), iron, .004)
            for x in (.02, 1.38): boxab((x - .025, -.025, .05), (x + .025, .025, 1.75), iron, .004)
            for i in range(1, 14):
                cyl(.01, .77, (i * .1, 0, .465), iron, n=6, bv=0)
            for i in range(7):                                          # hoa văn quả trám nửa trên
                cx = .1 + i * .2
                pts = [(cx - .1, 0, 1.28), (cx, 0, 1.68), (cx + .1, 0, 1.28), (cx, 0, .89), (cx - .1, 0, 1.28)]
                curve(pts, .009, iron)
            boxab((1.2, -.06, .95), (1.42, -.03, .99), M(C['steel'], .3, .9), .003)     # then cài
            if not st: box((.06, .03, .08), (1.33, -.07, .9), M('#C9A53A', .3, .9), .006)  # ổ khóa
        boxab((1.07, -.24, 1.35), (1.33, -.175, 1.6), M('#B83A2C', .5), .01)          # ô thư
    return g


def tuong_rao(st=None):
    """Tường rào sân, đoạn 2 m, cao 2,0 m, dày 0,2 m: vữa trát, mũ tường xi măng, chân rêu.
    Ghép nối liền nhiều đoạn quanh sân; bản game là một hộp có 2 màu (vữa, chân tường)."""
    g = group('tuong_rao')
    with at(g):
        boxab((-1, 0, 0), (1, .2, 2.0), M(PLASTER2, .92), .01)
        boxab((-1.01, -.03, 2.0), (1.01, .23, 2.08), M(CONCRETE, .88), .015)
        boxab((-1, -.01, 0), (1, 0, .3), M(PLINTH, .95), 0)
        moss(-.3, .8, seed=9)
        brick_patch(.2, 1.1, 2, 3, 0, seed=11)
    return g


# =============================================================== CÂY KHẾ

def _star_fruit(loc, s, mat, rot=0.0):
    """Trái khế: lăng trụ 5 cánh vuốt nhọn hai đầu, dài 9 cm."""
    n = 10; V = []; F = []
    rings = [(-.5, .15), (-.35, .75), (0, 1.0), (.35, .75), (.5, .15)]
    for zf, k in rings:
        for i in range(n):
            a = 2 * math.pi * i / n; r = (.035 if i % 2 == 0 else .018) * k
            V.append((r * math.cos(a), r * math.sin(a), zf * .09))
    for j in range(len(rings) - 1):
        for i in range(n):
            F.append((j * n + i, j * n + (i + 1) % n, (j + 1) * n + (i + 1) % n, (j + 1) * n + i))
    V.append((0, 0, -.05)); V.append((0, 0, .05)); b0 = len(V) - 2
    for i in range(n): F.append(((i + 1) % n, i, b0)); F.append(((len(rings) - 1) * n + i, (len(rings) - 1) * n + (i + 1) % n, b0 + 1))
    o = mesh_obj('khe', [tuple(np.array(v) * s) for v in V], F, mat, loc, (0.25, 0, rot), smooth=True)
    return o


def cay_khe(st=None):
    """Cây khế sân sau cao 3,6 m: thân nâu xám cong, chia 3 nhánh ở 1,3 m, tán rộng ø3,2 m nhiều chùm lá nhỏ xanh đậm.
    Trái khế vàng xanh treo dưới tán (chỗ thấp nhất 1,6 m). Gốc có bồn gạch tròn ø1,0 m cao 0,25 m.
    Va chạm chỉ ở thân và bồn gốc; tán cây không chặn camera (tán mờ khi camera chui vào, A1)."""
    g = group('cay_khe')
    rnd = R(8)
    with at(g):
        bark = M('#6E5A48', .95); bark2 = M('#5E4C3C', .95)
        cyl(.5, .25, (0, 0, .125), M(BRICK, .85), n=20, bv=.02)
        cyl(.44, .02, (0, 0, .25), M('#5A4434', .98), n=20, bv=0)
        trunk = [(0, 0, .2), (.05, .02, .7), (-.04, .05, 1.1), (0, 0, 1.35)]
        curve(trunk, .13, bark)
        tips = []
        for i, (a, l, up) in enumerate(((.3, 1.1, 1.2), (2.4, 1.0, 1.0), (4.3, 1.2, 1.1))):
            p0 = np.array((0, 0, 1.3)); mid = p0 + np.array((math.cos(a) * l * .5, math.sin(a) * l * .5, up * .6))
            tip = p0 + np.array((math.cos(a) * l, math.sin(a) * l, up)); tips.append(tip)
            curve([tuple(p0), tuple(mid), tuple(tip)], .07, bark2 if i % 2 else bark)
        leafc = ['#3E6F3A', '#4E8A4A', '#355F33']
        for i in range(34):
            t = tips[i % 3]; a = rnd.uniform(0, 6.28); r = rnd.uniform(0, 1.0)
            p = (t[0] * .8 + math.cos(a) * r, t[1] * .8 + math.sin(a) * r, 2.3 + rnd.uniform(0, 1.1))
            ball(rnd.uniform(.38, .6), p, M(leafc[i % 3], .85, sheen=.3), scale=(1, 1, .7), sub=2)
        for i in range(22):
            a = rnd.uniform(0, 6.28); r = rnd.uniform(.6, 1.3)
            _star_fruit((math.cos(a) * r, math.sin(a) * r, rnd.uniform(1.7, 2.25)), 1.8,
                        M('#D8C43A' if i % 3 else '#A9C24A', .45, coat=.3), rot=rnd.uniform(0, 3))
    return g


# =============================================================== BỒN KIỂNG

def bon_kieng(st=None):
    """Bồn kiểng xây gạch dài 2,0 m, rộng 0,6 m, cao 0,5 m (Bơ bước lên được), thành gạch thẻ lộ, mép xi măng.
    Trồng rau thơm của Cô Ba: sả, lá lốt, ớt chỉ thiên, ngò gai, một khóm cúc vạn thọ. Ghép 4–5 đoạn thành bồn dài 9 m."""
    g = group('bon_kieng')
    rnd = R(3)
    with at(g):
        for zr in range(6):
            off = .1 if zr % 2 else 0
            for c in range(11):
                x = -1 + off + c * .2
                if x + .19 > 1.0: continue
                for y in (-.29, .29):
                    box((.19, .02, .075), (x + .09, y, .04 + zr * .08), M(BRICK if (c + zr) % 3 else BRICK2, .85), .003)
            for x in (-.99, .99):
                box((.02, .56, .075), (x, 0, .04 + zr * .08), M(BRICK2, .85), .003)
        for a, b in (((-1.02, -.32), (1.02, -.24)), ((-1.02, .24), (1.02, .32)), ((-1.02, -.24), (-.94, .24)), ((.94, -.24), (1.02, .24))):
            boxab((a[0], a[1], .48), (b[0], b[1], .52), M(CONCRETE, .85), .01)   # mép xi măng quanh miệng bồn
        boxab((-.94, -.24, .3), (.94, .24, .47), M('#5A4434', .98), 0)              # đất
        # sả
        for x in (-.75, -.6):
            for k in range(7):
                a = k * .9
                curve([(x, 0, .5), (x + math.cos(a) * .08, math.sin(a) * .08, .85), (x + math.cos(a) * .22, math.sin(a) * .22, .95)], .008, M('#7FA651', .8))
        # lá lốt
        for i in range(10):
            ball(.07, (-.3 + rnd.uniform(-.12, .12), rnd.uniform(-.15, .15), .58 + rnd.uniform(0, .08)), M('#3E7A3E', .7, sheen=.3), scale=(1, 1, .35), sub=1)
        # ớt chỉ thiên
        for i in range(5):
            ball(.09, (.15 + rnd.uniform(-.1, .1), rnd.uniform(-.12, .12), .68 + rnd.uniform(0, .1)), M('#4E8A4A', .8, sheen=.3), sub=1)
        for i in range(8):
            cyl(.008, .05, (.15 + rnd.uniform(-.12, .12), rnd.uniform(-.14, .14), .78 + rnd.uniform(0, .08)), M(C['red'], .4, coat=.4), n=6, bv=0)
        # cúc vạn thọ
        for i in range(6):
            ball(.06, (.65 + rnd.uniform(-.15, .15), rnd.uniform(-.12, .12), .65 + rnd.uniform(0, .06)), M('#4E8A4A', .8), sub=1)
        for i in range(5):
            ball(.04, (.65 + rnd.uniform(-.14, .14), rnd.uniform(-.12, .12), .73 + rnd.uniform(0, .05)), M('#F2A13D', .7, sheen=.4), sub=1)
    return g


ITEMS = [
    # id, hàm, nhóm, tên, trạng thái phụ, ngân sách tam giác bản game
    ('mat_sau_lo', mat_sau_lo, 'nha', 'Mặt sau Lò bánh', ['toi'], 1600),
    ('kho_cui', kho_cui, 'nha', 'Kho củi mái tôn', [], 1200),
    ('cong_sau', cong_sau, 'rao', 'Cổng sắt ra hẻm', ['mo'], 700),
    ('tuong_rao', tuong_rao, 'rao', 'Tường rào (đoạn 2 m)', [], 80),
    ('cay_khe', cay_khe, 'cay', 'Cây khế', [], 1500),
    ('bon_kieng', bon_kieng, 'cay', 'Bồn kiểng rau thơm (đoạn 2 m)', [], 600),
]
BY_ID = {i[0]: i for i in ITEMS}
