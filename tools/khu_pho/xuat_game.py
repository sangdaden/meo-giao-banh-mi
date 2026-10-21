"""Xuất nhà và đồ phố (trang "Khu phố Lò Bánh" đã duyệt 21/10) ra .glb nhẹ cho game.

Dựng lại bằng kit.py (chép từ /mnt/project-files/khu-pho/kit.py), bỏ bevel, giảm lưới,
gộp mỗi món thành một mesh với một vật liệu và màu đỉnh COLOR_0 (giống đồ bếp).
Đơn vị mét thật. Gốc giữ như trong kit: nhà thì x 0..w, mặt tiền ở y = 0 (Godot z = 0,
thân nhà lùi về -z), đồ phố thì gốc ở giữa đáy.

Dùng: pip install bpy==5.2.0 numpy; python3 tools/khu_pho/xuat_game.py assets/models/pho
In ra assets/models/pho/manifest.json (số tam giác, kích thước) để kiểm tra.
Chỉ xuất vài món: thêm danh sách tên, ví dụ  ... assets/models/pho nha_A,xe_may_do
Đặt DEM=1 để in số tam giác của từng loại chi tiết trước khi giảm lưới (tìm chỗ nặng).
"""
import sys, os, math, json, random
import numpy as np
import bpy
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import kit
from kit import *

OUT = sys.argv[1] if len(sys.argv) > 1 else 'assets/models/pho'
ONLY = sys.argv[2].split(',') if len(sys.argv) > 2 else None
os.makedirs(OUT, exist_ok=True)
kit.FONT = next((f for f in ('/usr/share/fonts/opentype/inter/Inter-ExtraBold.otf', '/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf') if os.path.exists(f)), kit.FONT)

DEPTH = 7.3   # sâu nhà ống trong city.gd: (21 - 2*2 - 2,4) / 2
G0 = 3.4      # tầng trệt kit.nha_ong
F = 3.1


# ---------------------------------------------------------------- bản nhẹ cho game
# Bớt cạnh tròn của trụ, xuyến, cầu và bớt lá sách cửa sổ trước khi giảm lưới,
# để giảm lưới (decimate) chỉ phải gọt ít, hình khối vẫn giữ như bản phác.
_cyl, _torus, _ball, _box = kit.cyl, kit.torus, kit.ball, kit.box

def _g_cyl(r, h, loc, mat, rot=(0, 0, 0), n=24, r2=None, bv=.01, name='tru', smooth=True):
    return _cyl(r, h, loc, mat, rot, n=max(6, min(n, 10)), r2=r2, bv=0, name=name, smooth=smooth)

def _g_torus(R, r, loc, mat, rot=(0, 0, 0), n=32, m=12, name='vong'):
    return _torus(R, r, loc, mat, rot, n=max(8, min(n, 14)), m=min(m, 5), name=name)

def _g_ball(r, loc, mat, scale=(1, 1, 1), sub=2, name='cau'):
    return _ball(r, loc, mat, scale, sub=min(sub, 1 if r < .4 else 2), name=name)

def _g_box(size, loc, mat, bv=.015, rot=(0, 0, 0), name='hop'):
    # lá sách cửa (hộp mỏng nghiêng 0,6 rad) chỉ giữ 1/2
    if rot and abs(rot[0] - .6) < 1e-6 and size[2] <= .012:
        _g_box.k = getattr(_g_box, 'k', 0) + 1
        if _g_box.k % 2: return None
    return _box(size, loc, mat, 0, rot, name)

_corr = kit.corrugated

def _g_corr(w, l, mat, loc, rot=(0, 0, 0), period=.076, amp=.012, thick=.006, name='ton'):
    # sóng thưa hơn (mỗi sóng vẫn 6 điểm) và tấm không dày: một nửa số tam giác
    o = _corr(w, l, mat, loc, rot, period=period * 1.8, amp=amp * 1.3, thick=thick, name=name)
    for md in list(o.modifiers): o.modifiers.remove(md)   # game vẽ hai mặt (cull tắt) nên khỏi làm dày
    return o

kit.cyl, kit.torus, kit.ball, kit.box, kit.corrugated = _g_cyl, _g_torus, _g_ball, _g_box, _g_corr
cyl, torus, ball, box, corrugated = _g_cyl, _g_torus, _g_ball, _g_box, _g_corr


def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    kit._MATS.clear(); kit.PARENT[0] = None


# ---------------------------------------------------------------- nhà đặc biệt, bản cho game
# Chép từ pho.py, bỏ đồ rời (xe, bàn ghế, thùng) vì game tự đặt chúng có va chạm riêng.

def lo_banh():
    w = 5.2
    g = nha_ong('lo_banh', (0, 0, 0), w=w, floors=2, wall='cream', ground='open', uppers=['window'], roof='pediment', seed=2)
    with at(g):
        sign_board(w / 2, 3.45, w - .4, .8, -.3, '#C8412F', '#FFF3D6', 'LÒ BÁNH MÌ CÔ BA', 'bánh mì nóng · từ 1968')
        box((.6, .05, .8), (.55, -.25, .5), M('#2A3A30', .8), .02, rot=(-.15, 0, 0))   # bảng phấn sát tường
        for i, t in enumerate(('pate 15k', 'thịt 20k', 'chả cá 20k')):
            text(t, .08, (.55, -.29, .75 - i * .14), M(C['white'], .8), extrude=.002, rot=(math.pi / 2 - .15, 0, 0))
        # Hai đèn lồng không dính vào nhà: city_props.gd đặt den_long (hoặc đèn lồng tiệm người chơi mua) ở (.6, -.25, 2.45) và (w - .6, -.25, 2.45)
    return g


def xe_banh_mi():
    """Xe tủ kính bánh mì trước lò (main.gd đặt ở chỗ khối tạm cũ, có va chạm riêng)."""
    gg = group('xe_banh_mi', (0, 0, 0))
    with at(gg):
        box((1.6, .7, .7), (0, 0, .45), M(C['shutter'], .5), .03)
        box((1.6, .7, .45), (0, 0, 1.03), M('#CFE8EA', .05), .01)
        for sx in (-.8, .8):
            for sy in (-.35, .35): box((.04, .04, .5), (sx, sy, 1.03), M(C['steel'], .3, .8), 0)
        box((1.64, .74, .04), (0, 0, 1.27), M(C['steel'], .3, .8), .01)
        for i in range(5): cyl(.045, .42, (-.55 + i * .27, .05, .86), M('#D98E2B', .6), rot=(math.pi / 2, 0, .2), n=10, r2=.035)
        text('BÁNH MÌ', .2, (0, -.36, 1.03), M('#C8412F', .5), extrude=.008)
        for sx in (-.6, .6): torus(.11, .035, (sx, -.36, .11), M('#222222', .8), rot=(0, math.pi / 2, math.pi / 2), n=14, m=6)
    return gg


def chung_cu(floors=5, units=4, uw=4.2, d=8.3):
    """Chung cư Hoa Sữa: hành lang (mặt trước, -y) quay ra hẻm giữa khối 3, ban công Bé Na là hành lang tầng 3."""
    w = units * uw; F_ = 3.0; H = F_ * floors
    g = group('chung_cu', (0, 0, 0)); wall = M('#D9C9A0', .9); wall2 = M('#C8B88E', .9)
    with at(g):
        boxab((0, 1.6, 0), (w, d, H), wall, 0)
        for f in range(floors):
            z = f * F_
            boxab((-.1, -.1, z - .1 if f else -.05), (w + .1, 1.7, z + .12), M('#E6DCC4', .85), 0)
            for u in range(units):
                x0 = u * uw
                boxab((x0 + .3, 1.55, z + .12), (x0 + 1.2, 1.62, z + 2.2), M(['#3E6E6E', '#7A4E36', '#4A5E7A'][(u + f) % 3], .6), 0)
                louver_window(x0 + 2.6, z + 1.0, 1.3, 1.1, 1.6, '#D9C9A0', C['shutter'] if (u + f) % 2 else '#6E8F5E', open_=.4 + .4 * ((u * f) % 2))
                if (u + f) % 3 == 0: ac_unit((x0 + 2.6, 1.45, z + 2.55), 0)
                if f and (u * 3 + f) % 4 == 1: plant_pot((x0 + 1.6, .5, z + .12), kind='bush', s=.6)
                if f and (u + 2 * f) % 3 == 1: laundry(x0 + .4, x0 + uw - .4, .4, z + 2.6, seed=u * 7 + f)
            if f > 0: railing(0, w, -.05, z + .12, h=1.05, deco=False)
            for u in range(units + 1):
                boxab((u * uw - .15, -.15, z), (u * uw + .15, .15, z + F_), M('#E6DCC4', .85), 0)
        boxab((-.2, -.25, H - .05), (w + .2, d + .2, H + .25), M('#E6DCC4', .85), 0)
        for i in range(3): water_tank((1.5 + i * 5.0, d - 1.5, H + .25), horizontal=bool(i % 2))
        antenna((4, 3.5, H + .25)); antenna((11, 3.5, H + .25))
        railing(0, w, -.1, H + .25, h=.9, deco=False)
        # khối cầu thang gạch bông gió (bản game: ô bông gió là hộp phẳng, không xuyến)
        sx = w; bm = M('#E6DCC4', .85)
        boxab((sx, 0, 0), (sx + 2.6, d * .7, H + 1.0), wall2, 0)
        for f in range(floors):
            for i in range(5):
                for j in range(6):
                    cx = sx + .3 + i * .45; cz = f * F_ + .7 + j * .32
                    boxab((cx - .14, -.04, cz - .1), (cx + .14, 0, cz + .1), M('#8E826A', .9), 0)
                    boxab((cx - .02, -.05, cz - .1), (cx + .02, 0, cz + .1), bm, 0)
                    boxab((cx - .14, -.05, cz - .015), (cx + .14, 0, cz + .015), bm, 0)
            boxab((sx, -.08, f * F_ + .55), (sx + 2.6, .0, f * F_ + .65), bm, 0)
        text('CHUNG CƯ HOA SỮA', .38, (w / 2, -.26, H - .45), M('#8A3A2A', .6), extrude=.02)
        text('LÔ B', .5, (sx + 1.3, -.1, H + .4), M('#8A3A2A', .6), extrude=.02)
        boxab((sx + .5, -.1, 0), (sx + 2.1, .05, 2.4), M('#1E2424', .6), 0)
        boxab((sx + .3, -.4, 2.4), (sx + 2.3, .1, 2.6), M('#E6DCC4', .85), 0)
    return g


def cafe_may():
    w = 6.0
    g = nha_ong('cafe_may', (0, 0, 0), w=w, floors=2, wall='blue', ground='open', uppers=['balcony'], roof='ton', seed=3)
    with at(g):
        # bảng hiệu gắn trước lan can ban công (dưới ban công là mái hiên 2,9 m của game)
        sign_board(w / 2, 3.95, w - .6, .75, -1.03, '#F1ECE2', '#2457A0', 'CÀ PHÊ MÂY', 'cà phê sữa đá · bạc xỉu')
        for k, (dx, r) in enumerate(((-.35, .18), (0, .24), (.35, .17))): ball(r, (w - .9 + dx, -1.1, 3.95 + (.06 if k == 1 else 0)), M(C['white'], .8), (1, .3, .8))
        boxab((.5, .6, 0), (2.6, 1.2, 1.05), M(C['wood2'], .6), 0)    # quầy trong quán
        boxab((.45, .55, 1.05), (2.65, 1.25, 1.1), M(C['wood'], .5), 0)
        for i in range(3): cyl(.06, .18, (.9 + i * .5, .9, 1.2), M(C['steel'], .3, .9), n=10)
        plant_pot((.3, -.5, 0), kind='palm', s=1.0); plant_pot((w - .3, -.5, 0), kind='bush', s=1.0)
    return g


def sua_xe(w=5.5, door_x=2.8):
    """Tiệm sửa xe Hùng: trệt rỗng xuyên tới cửa sau (game đi xuyên được), lầu 1 cửa sổ, mái tôn."""
    g = group('sua_xe', (0, 0, 0)); wallc = '#A9B7B4'; wm = M(wallc, .88)
    with at(g):
        H = G0 + F
        for sx in (0, w - .28): boxab((sx, 0, 0), (sx + .28, DEPTH, H), wm, 0)           # hai vách hông
        boxab((.12, .3, G0 - .32), (w - .12, DEPTH, H), wm, 0)                             # lầu
        boxab((0, 0, G0 - .4), (w, .45, G0), wm, 0)
        boxab((.28, .3, -.01), (w - .28, DEPTH - .2, .02), M('#6E6A62', .8), 0)            # nền láng dầu
        boxab((.28, .3, G0 - .34), (w - .28, DEPTH - .2, G0 - .32), M('#5E6F6C', .9), 0)   # trần
        dw = 1.2                                                                             # tường sau có cửa
        boxab((.28, DEPTH - .2, 0), (door_x - dw / 2, DEPTH, G0 - .3), wm, 0)
        boxab((door_x + dw / 2, DEPTH - .2, 0), (w - .28, DEPTH, G0 - .3), wm, 0)
        boxab((door_x - dw / 2, DEPTH - .2, 2.2), (door_x + dw / 2, DEPTH, G0 - .3), wm, 0)
        boxab((door_x - dw / 2 - .1, DEPTH - .25, 2.2), (door_x + dw / 2 + .1, DEPTH + .02, 2.32), M(C['wood'], .7), 0)
        boxab((.05, -.25, G0 - .1), (w - .05, .45, G0 + .1), M(C['white'], .8), 0)
        louver_window(w / 2, G0 + .8, min(1.6, w - 1.2), 1.5, .3, wallc, C['shutter'])
        ac_unit((w - .7, .1, G0 + .6), 0)
        boxab((0, 0, H), (w, .3, H + .5), wm, 0); roof_ton(w, DEPTH, H + .5, C['ton_blue'])
        sign_board(w / 2, 3.45, w - .4, .8, -.3, '#2457A0', '#F2B33D', 'SỬA XE HÙNG', 'vá xe · thay nhớt · bơm hơi')
        box((1.6, .05, 1.0), (w - 1.3, 1.9, 1.6), M('#5A4E44', .8), 0)                       # bảng đồ nghề
        for i in range(8): box((.04, .03, .25 + (i % 3) * .05), (w - 2.0 + i * .18, 1.86, 1.6), M(C['steel'], .35, .9), 0)
        text('BƠM HƠI', .16, (w - .5, -.37, 1.6), M('#C8412F', .5), extrude=.004)
        box((.7, .04, .4), (w - .5, -.33, 1.6), M(C['white'], .6), 0)
    return g


def nha_ba_sau(depth=3.6):
    w = 6.0
    g = nha_ong('nha_ba_sau', (0, 0, 0), w=w, floors=2, depth=depth, wall='pink', ground='gate', uppers=['balcony'], roof='ngoi', seed=6)
    with at(g):
        boug_cascade(.1, w - .1, -1.0, 4.4, drop=2.0, seed=6)
        boug_cascade(w - 1.2, w + .2, -1.4, 6.8, drop=6.0, seed=9)
        cyl(.06, 6.8, (w - .4, -1.6, 3.4), M('#6A5040', .9), n=8)
        for (x0, x1) in ((0, 1.6), (4.4, w)):
            boxab((x0, -2.2, 0), (x1, -2.0, .8), M(C['pink'], .88), 0)
            boxab((x0, -2.2, .8), (x1, -2.0, .9), M(C['white'], .8), 0)
            railing(x0 + .1, x1 - .1, -2.1, .9, h=.8, deco=False)
        for sx in (1.6, 4.4): boxab((sx - .15, -2.25, 0), (sx + .15, -1.95, 2.0), M(C['pink'], .88), 0)
        folding_gate(1.75, 4.25, 0, 1.9, -2.1)
        for x in (.6, 1.1, 5.0, 5.5): plant_pot((x, -1.3, 0), kind=random.Random(int(x * 10)).choice(['boug', 'bush', 'palm']), s=.8)
        long_chim((w / 2, -.5, 2.0))
        box((.6, .04, .4), (w / 2, -2.27, 1.7), M('#E9E2D2', .6), 0)
        text('42/7', .18, (w / 2, -2.3, 1.7), M('#2457A0', .6), extrude=.004)
    return g


def tap_hoa():
    w = 4.4
    # Tiệm đi vào được hết lòng (shop_tap_hoa.gd: sâu 7,3 m, cửa sau ra hẻm giữa khối ở góc x 0,2..0,95)
    g = nha_ong('tap_hoa', (0, 0, 0), w=w, floors=3, wall='salmon', ground='open', uppers=['cage', 'balcony'], roof='flat', seed=8,
                shop_d=7.1, back_door=(.2, .95, 1.4))
    with at(g):
        sign_board(w / 2, 3.45, w - .4, .8, -.3, '#3F8A5C', '#FFF3D6', 'TẠP HÓA CÔ HAI', 'nước ngọt · gạo · mì gói')
        # Đồ trong tiệm (quầy, kệ, bao gạo, tủ kem, dây snack) là model riêng của trang "Phác thảo Thứ Ba",
        # scripts/shop_tap_hoa.gd đặt vào; vỏ tiệm chỉ còn nhà và bảng hiệu.
    return g


# Nhà lấp chỗ trống: đủ cỡ rộng để city.gd ghép kín dãy phố (dãy cuối giãn nhẹ trục x).
FILLERS = [
    dict(name='nha_A', w=4.0, floors=3, wall='teal', uppers=['balcony', 'window'], roof='flat', ground='shutter', seed=11),
    dict(name='nha_B', w=3.8, floors=4, wall='pink', uppers=['cage', 'balcony', 'window'], roof='ton', ground='shutter', seed=12),
    dict(name='nha_C', w=4.6, floors=2, wall='mustard', uppers=['balcony'], roof='ngoi', ground='gate', seed=13),
    dict(name='nha_D', w=5.0, floors=3, wall='mint', uppers=['window', 'balcony'], roof='pediment', ground='shutter', seed=14),
    dict(name='nha_E', w=4.2, floors=2, wall='salmon', uppers=['window'], roof='ton', ground='shutter', seed=15, sign=('#F2B33D', '#2E2E2E', 'PHỞ', None)),
    dict(name='nha_F', w=5.5, floors=3, wall='blue', uppers=['balcony', 'balcony'], roof='flat', ground='shutter', seed=16),
    dict(name='nha_G', w=4.4, floors=4, wall='cream', uppers=['window', 'cage', 'balcony'], roof='flat', ground='gate', seed=17),
    dict(name='nha_H', w=5.8, floors=2, wall='teal', uppers=['balcony'], roof='ngoi', ground='shutter', seed=18, sign=('#C8412F', '#FFF3D6', 'CƠM TẤM', None)),
    dict(name='nha_I', w=3.6, floors=3, wall='mustard', uppers=['cage', 'window'], roof='ton', ground='shutter', seed=19),
    dict(name='nha_K', w=4.8, floors=3, wall='pink', uppers=['balcony', 'window'], roof='pediment', ground='shutter', seed=20, sign=('#2457A0', '#FFF3D6', 'TIỆM TÓC', None)),
]


def filler(f):
    f = dict(f); name = f.pop('name'); sign = f.pop('sign', None)
    g = nha_ong(name, (0, 0, 0), depth=DEPTH, **f)
    if sign:   # bảng hiệu: trước lan can nếu tầng 1 có ban công, không thì trên mái hiên game (2,9 m)
        w = f['w']
        with at(g):
            if f['uppers'][0] == 'balcony': sign_board(w / 2, 3.95, w - .6, .7, -1.03, *sign)
            else: sign_board(w / 2, 3.45, w - .5, .7, -.3, *sign)
    return g


# ---------------------------------------------------------------- đồ phố
def mai_hien(cols):
    """Mái hiên bạt 1 m rộng (game giãn theo bề ngang nhà), sâu 1 m, gần phẳng để khớp tấm va chạm 2,9 m."""
    awning(-.5, .5, 0, 0, depth=1.0, stripes=cols, drop=.08)


def day_phoi(cols, seed):
    """Dây phơi 2,4 m ngang hẻm: 3 tấm 0,62 x 0,9 m đúng chỗ khối va chạm của game (tâm -0,75 / 0 / 0,75), xen đồ nhỏ."""
    rnd = random.Random(seed)
    cyl(.012, 2.4, (0, 0, 0), M(C['steel'], .4, .7), rot=(0, math.pi / 2, 0), bv=0)
    for i, c in enumerate(cols):
        x = -.75 + i * .75
        o = box((.62, .02, .9), (x, 0, -.47), M(c, .95, sheen=.7), 0); o.rotation_euler = (rnd.uniform(-.05, .05), 0, 0)
        for sx in (-.25, .25): box((.03, .03, .05), (x + sx, 0, -.01), M('#E8D9B5', .6), 0)   # kẹp
    for x in (-1.12, -.375, .375, 1.12):
        box((.12, .015, .3), (x, 0, -.17), M(rnd.choice(['#E9E2D2', '#3A6EA5', '#F2B33D', '#7FB7A4']), .95), 0)


def sap_bao_game():
    """Sạp báo Chú Tư bản game: bỏ dù (mái hiên 2,9 m che rồi)."""
    g = group('sap_bao', (0, 0, 0))
    with at(g):
        wm = M('#2E7C80', .6); wd = M('#8A5A30', .7)
        box((1.6, .7, .9), (0, 0, .45), wm, 0); box((1.7, .8, .05), (0, 0, .92), wd, 0)
        box((1.6, .08, 1.3), (0, .36, 1.6), wm, 0)
        rnd = random.Random(4); cols = ['#EDE6D3', '#F2E3B8', '#E9C8A0', '#D9E3E8', '#F6D6D0', '#E6E0C8']
        for r_ in range(3):
            for k in range(5):
                box((.26, .02, .34), (-.6 + k * .3, .31, 1.15 + r_ * .4), M(rnd.choice(cols), .9), 0)
                box((.18, .021, .04), (-.6 + k * .3, .30, 1.26 + r_ * .4), M(rnd.choice(['#C8412F', '#2457A0', '#222222']), .7), 0)
        for k in range(6): box((.38, .3, .03), (-.6 + k * .24, -.05, .96 + (k % 2) * .02), M(rnd.choice(cols), .9), 0, rot=(0, 0, rnd.uniform(-.2, .2)))
        text('BÁO', .22, (0, -.36, .5), M(C['white'], .5), extrude=.006)
    return g


PROPS = {
    'xe_banh_mi': xe_banh_mi,
    'xe_may_do': lambda: xe_may((0, 0, 0), col='#C8412F'),
    'xe_may_den': lambda: xe_may((0, 0, 0), col='#2E2E2E'),
    'xe_may_xanh': lambda: xe_may((0, 0, 0), col='#3A6EA5'),
    'xe_may_trang': lambda: xe_may((0, 0, 0), col='#E9E2D2'),
    'xe_may_son': lambda: xe_may((0, 0, 0), col=SON),   # sơn trắng tách vật liệu "son" để traffic.gd tô màu từng xe
    'ba_gac': lambda: xe_ba_gac((0, 0, 0), load=False),
    'thung_go': lambda: thung_hang((0, 0, 0), s=.8),
    'thung_xop': lambda: thung_hang((0, 0, 0), s=.8, kind='xop'),
    'chau_bui': lambda: plant_pot((0, 0, 0), kind='bush'),
    'chau_boug': lambda: plant_pot((0, 0, 0), kind='boug'),
    'chau_cau': lambda: plant_pot((0, 0, 0), kind='palm'),
    'cot_dien': lambda: cot_dien((0, 0, 0)),
    'den_duong': lambda: den_duong((0, 0, 0)),
    'bien_duong': lambda: bien_ten_duong((0, 0, 0)),
    'thung_rac': lambda: thung_rac((0, 0, 0)),
    'cay_xanh': lambda: cay_xanh((0, 0, 0)),
    'cuu_hoa': lambda: tru_cuu_hoa((0, 0, 0)),
    'binh_gas': lambda: binh_gas((0, 0, 0)),
    'ban_nhua': lambda: ban_nhua((0, 0, 0), col='#E9E2D2'),
    'ghe_do': lambda: ghe_nhua((0, 0, 0), C['plastic_red']),
    'ghe_xanh': lambda: ghe_nhua((0, 0, 0), C['plastic_blue']),
    'sap_bao': sap_bao_game,
    'ban_co': lambda: ban_co((0, 0, 0)),
    'lop_xe': lambda: lop_xe_chong((0, 0, 0), 4),
    'may_nen': lambda: may_nen_khi((0, 0, 0)),
    'ban_nang': lambda: (be_cau((0, 0, 0)), xe_may((0, 0, .6), rot=0, col='#2E2E2E')),
    'day_phoi_a': lambda: day_phoi(('#F2E3B8', '#E39C7A', '#A9C7E8'), 4),
    'day_phoi_b': lambda: day_phoi(('#D7A9C4', '#FFF8EA', '#7FB7A4'), 5),
    'mai_hien_do': lambda: mai_hien(('#D9553F', '#F1ECE2')),
    'mai_hien_xanh': lambda: mai_hien(('#3A6EA5', '#F1ECE2')),
    'mai_hien_la': lambda: mai_hien(('#3F8A5C', '#F1ECE2')),
    'mai_hien_vang': lambda: mai_hien(('#E2A93B', '#F1ECE2')),
    'o_cho': lambda: o_cho((0, 0, 0)),
    'den_long': lambda: den_long((0, 0, 0)),
}

SPECIALS = ('lo_banh', 'chung_cu', 'cafe_may', 'sua_xe', 'nha_ba_sau', 'tap_hoa')
BUILDINGS = dict(lo_banh=lo_banh, chung_cu=chung_cu, cafe_may=cafe_may, sua_xe=sua_xe, nha_ba_sau=nha_ba_sau, tap_hoa=tap_hoa)
for _f in FILLERS: BUILDINGS[_f['name']] = (lambda f=_f: filler(f))

SON = '#FFFFFE'   # màu đánh dấu phần sơn xe (xe_may_son)

# Trần số tam giác: quá thì giảm lưới (collapse), giữ khối chính.
TARGET = dict(nha_G=4000, nha_C=3500, chung_cu=12000, nha_ba_sau=8000, cay_xanh=900, xe_may_son=900, xe_may_do=900, xe_may_den=900, xe_may_xanh=900, xe_may_trang=900,
              ba_gac=1200, ban_nang=1100, sap_bao=900, o_cho=700, xe_banh_mi=900)
BUILDING_TARGET = 2500
SPECIAL_TARGET = 7000
PROP_TARGET = 600


def _flat(m):
    if m is None: return (.8, .8, .8)
    b = m.node_tree.nodes.get('Principled BSDF') if m.node_tree else None
    return tuple(b.inputs['Base Color'].default_value[:3]) if b else (.8, .8, .8)


def _lighten():
    """Bỏ bevel, giảm độ phân giải chữ: hộp còn 12 tam giác thay vì ~150."""
    for o in bpy.context.scene.objects:
        for md in list(o.modifiers):
            if md.type == 'BEVEL': o.modifiers.remove(md)
        if o.type == 'FONT': o.data.resolution_u = 2; o.data.bevel_depth = 0
        if o.type == 'CURVE': o.data.bevel_resolution = 0; o.data.use_fill_caps = False   # dây, song cổng xếp: ống 4 cạnh


_dem = {}

def export(name, out):
    _dem.clear()
    _lighten()
    dg = bpy.context.evaluated_depsgraph_get()
    sc = bpy.context.scene
    parts = []
    for o in list(sc.objects):
        if o.type not in ('MESH', 'FONT', 'CURVE'): continue
        me = bpy.data.meshes.new_from_object(o.evaluated_get(dg))
        if len(me.polygons) == 0: continue
        me.transform(o.matrix_world)
        cols = [_flat(s.material) if s.material else _flat(o.active_material) for s in o.material_slots] or [_flat(o.active_material)]
        col = np.zeros((len(me.vertices), 4), np.float32); col[:, 3] = 1
        for p in me.polygons:   # màu theo vật liệu từng mặt (chữ, cửa...)
            c = cols[min(p.material_index, len(cols) - 1)]
            col[list(p.vertices), :3] = c
        ca = me.color_attributes.new('Col', 'FLOAT_COLOR', 'POINT'); ca.data.foreach_set('color', col.ravel())
        me.materials.clear()
        p = bpy.data.objects.new(name, me); sc.collection.objects.link(p); parts.append(p)
        if os.environ.get('DEM'): _dem[o.name.split('.')[0]] = _dem.get(o.name.split('.')[0], 0) + sum(len(q.vertices) - 2 for q in me.polygons)
    if _dem: print('dem', name, sorted(_dem.items(), key=lambda kv: -kv[1])[:8])
    for o in list(sc.objects):
        if o not in parts: bpy.data.objects.remove(o, do_unlink=True)
    bpy.ops.object.select_all(action='DESELECT')
    for p in parts: p.select_set(True)
    bpy.context.view_layer.objects.active = parts[0]
    if len(parts) > 1: bpy.ops.object.join()
    g = bpy.context.active_object; g.name = name; me = g.data
    bpy.ops.object.mode_set(mode='EDIT'); bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.mesh.remove_doubles(threshold=.0005); bpy.ops.object.mode_set(mode='OBJECT')
    tris = sum(len(pl.vertices) - 2 for pl in me.polygons)
    tgt = TARGET.get(name, (SPECIAL_TARGET if name in SPECIALS else BUILDING_TARGET) if name in BUILDINGS else PROP_TARGET)
    print('raw', name, tris)
    if tris > tgt:
        md = g.modifiers.new('Dec', 'DECIMATE'); md.ratio = tgt / tris; md.use_collapse_triangulate = True
        bpy.ops.object.modifier_apply(modifier='Dec')
    mat = bpy.data.materials.new('pho_mausac'); me.materials.append(mat)
    if name == 'xe_may_son':   # mặt nào mang màu SON thì sang vật liệu thứ hai tên "son"
        me.materials.append(bpy.data.materials.new('son'))
        son = np.array(lin(SON)[:3], np.float32); cc = np.empty(len(me.vertices) * 4, np.float32)
        me.color_attributes['Col'].data.foreach_get('color', cc); cc = cc.reshape(-1, 4)
        for pl in me.polygons:
            if all(np.abs(cc[v, :3] - son).max() < .02 for v in pl.vertices): pl.material_index = 1
    me.color_attributes.active_color = me.color_attributes['Col']
    me.polygons.foreach_set('use_smooth', [False] * len(me.polygons))   # khối cứng: mặt phẳng
    co = np.empty(len(me.vertices) * 3, np.float32); me.vertices.foreach_get('co', co); co = co.reshape(-1, 3)
    lo, hi = co.min(0), co.max(0)
    tris = sum(len(pl.vertices) - 2 for pl in me.polygons)
    bpy.ops.export_scene.gltf(filepath=os.path.join(out, name + '.glb'), use_selection=True, export_apply=True,
                              export_vertex_color='ACTIVE', export_texcoords=False, export_normals=True,
                              export_materials='EXPORT' if name == 'xe_may_son' else 'PLACEHOLDER', export_yup=True)
    # Kích thước theo trục Godot: x, y (lên), z (Blender -y)
    return dict(tris=tris, min=[round(float(lo[0]), 3), round(float(lo[2]), 3), round(float(-hi[1]), 3)],
                max=[round(float(hi[0]), 3), round(float(hi[2]), 3), round(float(-lo[1]), 3)])


def main():
    mpath = os.path.join(OUT, 'manifest.json')
    manifest = json.load(open(mpath)) if os.path.exists(mpath) else {}
    for name, fn in list(BUILDINGS.items()) + list(PROPS.items()):
        if ONLY and name not in ONLY: continue
        reset(); fn()
        manifest[name] = export(name, OUT)
        print('exported', name, manifest[name])
    json.dump(manifest, open(mpath, 'w'), indent=1, ensure_ascii=False, sort_keys=True)


main()
