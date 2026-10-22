"""P2 · Bộ ráp nhà theo tầng + 5 nhà mốc (thiết kế lại khu phố, gói 3C).
Dựng bằng kit.py (Blender 5.2, Eevee, phong cách D). Toạ độ Blender: Z lên, mặt tiền ở y = 0 quay về -y,
x chạy dọc mặt tiền từ 0 tới w (gốc = góc trái mặt tiền, như nhà game hiện tại). Godot: x = x, y = z, z = -y.

Mảnh ghép:
  trệt (cao 3,4 m) 8 kiểu · lầu (cao 3,1 m) 6 kiểu · mái 5 kiểu · 10 màu sơn · bề ngang 3,2 / 4,0 / 4,8 / 6,0 m.
  Mỗi mảnh gồm luôn lát thân nhà sâu 7,3 m của tầng đó, nên chồng lên nhau là kín nhà.
Dùng: python3 bo_rap.py manh|nha|moc|xa|tat_ca <outdir>    (LITE=1: bản game, chỉ xuất .glb + meta, không render)
"""
import sys, os, math, json, random
import numpy as np
import bpy
HERE = os.path.dirname(os.path.abspath(__file__)); sys.path.insert(0, HERE)
import kit
LITE = bool(os.environ.get('LITE'))
# GAME=1 (tools/nha_rap/xuat_game.py): mảnh trệt không có bạt riêng (game có mái hiên 2,9 m liền dãy) và không có
# bảng hiệu (bảng xuất riêng từng tấm để game nâng lên trên mái hiên)
GAME = bool(os.environ.get('GAME'))
if LITE:   # như tools/khu_pho/xuat_game.py: bớt cạnh tròn, bớt lá sách, tôn không dày
    _cyl, _torus, _ball, _box, _corr = kit.cyl, kit.torus, kit.ball, kit.box, kit.corrugated
    def _g_cyl(r, h, loc, mat, rot=(0, 0, 0), n=24, r2=None, bv=.01, name='tru', smooth=True):
        return _cyl(r, h, loc, mat, rot, n=max(6, min(n, 10)), r2=r2, bv=0, name=name, smooth=smooth)
    def _g_torus(R, r, loc, mat, rot=(0, 0, 0), n=32, m=12, name='vong'):
        return _torus(R, r, loc, mat, rot, n=max(8, min(n, 12)), m=min(m, 4), name=name)
    def _g_ball(r, loc, mat, scale=(1, 1, 1), sub=2, name='cau'):
        return _ball(r, loc, mat, scale, sub=min(sub, 1), name=name)
    def _g_box(size, loc, mat, bv=.015, rot=(0, 0, 0), name='hop'):
        if rot and abs(rot[0] - .6) < 1e-6 and size[2] <= .012:
            _g_box.k = getattr(_g_box, 'k', 0) + 1
            if _g_box.k % 3: return None
        return _box(size, loc, mat, 0, rot, name)
    def _g_corr(w, l, mat, loc, rot=(0, 0, 0), period=.076, amp=.012, thick=.006, name='ton'):
        o = _corr(w, l, mat, loc, rot, period=period * 2.2, amp=amp * 1.3, thick=thick, name=name)
        for md in list(o.modifiers): o.modifiers.remove(md)
        return o
    kit.cyl, kit.torus, kit.ball, kit.box, kit.corrugated = _g_cyl, _g_torus, _g_ball, _g_box, _g_corr
from kit import *
from mathutils import Vector
if LITE:   # bản game: chữ bảng hiệu thành ảnh dán (atlas), cửa kéo không có thanh chéo, kệ hàng gộp khối
    def folding_gate(x0, x1, z0, z1, y):
        m = M(C['iron'], .5, .6); n = max(2, int((x1 - x0) / .2))
        for i in range(n + 1):
            x = x0 + i * (x1 - x0) / n; boxab((x - .015, y - .012, z0), (x + .015, y + .012, z1), m, 0)
        for z in (z0 + .1, (z0 + z1) / 2, z1 - .1): boxab((x0, y - .02, z - .02), (x1, y + .02, z + .02), m, 0)
    def ke_tap_hoa(loc, rot=0.0, w=1.8, h=2.0, seed=5):
        g = group('ke', loc, rot); rnd = random.Random(seed)
        cols = ['#C8412F', '#F2B33D', '#3A6EA5', '#3F8A5C', '#E9E2D2', '#D7A9C4', '#E8913A']
        with at(g):
            for sx in (-w / 2, w / 2): box((.04, .45, h), (sx, 0, h / 2), M(C['steel'], .4, .7), 0)
            for k in range(5):
                z = .1 + k * h / 5; box((w, .45, .025), (0, 0, z), M(C['steel'], .4, .7), 0)
                for i in range(4): box((w / 4 - .03, .3, h / 5 - .1), (-w / 2 + (i + .5) * w / 4, 0, z + h / 10), M(rnd.choice(cols), .7), 0)
        return g
    _rail = kit.railing
    def railing(x0, x1, y, z, h=1.0, mat=None, bar=.12, deco=True): return _rail(x0, x1, y, z, h, mat, bar=.16, deco=False)
    kit.railing = railing
    def text(*a, **k): return None
    kit.text = text

import bang_hieu as BH
from bang_hieu import bang_hieu
kit.FONT = next((f for f in ('/usr/share/fonts/opentype/inter/Inter-ExtraBold.otf', '/usr/share/fonts/opentype/inter/Inter-Bold.otf',
                             '/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf') if os.path.exists(f)), kit.FONT)
G0, F, D = 3.4, 3.1, 7.3
WIDTHS = (3.2, 4.0, 4.8, 6.0)
NIGHT = BH.NIGHT

# ---------------------------------------------------------------- 10 màu sơn (trầm hơn nhân vật một bậc, như kit.C)
SON = dict(vang_nghe='#E2C07E', xanh_ngoc='#77AD9C', cam_dat='#DB957A', bac_ha='#B6CFC8', kem='#EEDDB2',
           hong_phan='#CFA0BA', da_troi='#9FBEDD', vang_chanh='#DCD27A', la_non='#A9C68A', xam_trang='#D6D0C2')
SON_TEN = dict(vang_nghe='Vàng nghệ', xanh_ngoc='Xanh ngọc', cam_dat='Cam đất', bac_ha='Bạc hà', kem='Kem',
               hong_phan='Hồng phấn', da_troi='Da trời', vang_chanh='Vàng chanh', la_non='Lá non', xam_trang='Xám trắng')
TRIM = '#F1ECE2'

def W(paint): return M(SON.get(paint, paint), .88)
def glass(seed=0, strength=1.0):
    if NIGHT[0] and random.Random(seed).random() < .7: return M('#FFD58A', .3, emit=2.2 * strength)
    return M('#26302F', .25)

def gan(name, loc):
    """Điểm gắn cho đồ rời của P4 (bảng hiệu chìa, máy lạnh, chậu, dây phơi...). Thành Marker3D trong Godot."""
    e = bpy.data.objects.new(name, None); e.empty_display_size = .25; e.location = loc
    bpy.context.scene.collection.objects.link(e)
    if kit.PARENT[0] is not None: e.parent = kit.PARENT[0]
    return e

# ---------------------------------------------------------------- phần chung của mỗi tầng
def body_slice(w, z0, z1, paint, y0=.3):
    boxab((.12, y0, z0), (w - .12, D, z1), W(paint), .02)

def piers(w, z0, z1, paint, d=.45):
    for sx in (0, w - .28): boxab((sx, 0, z0), (sx + .28, d, z1), W(paint), .02)

def slab_lip(w, z):
    boxab((-.05, -.25, z - .1), (w + .05, .45, z + .1), M(TRIM, .8), .03)

def ground_base(w, paint, interior=True, wallin='#6D6152', floor='#9A8C78'):
    boxab((.12, 2.7, 0), (w - .12, D, G0), W(paint), .02)
    piers(w, 0, G0, paint)
    boxab((0, 0, G0 - .4), (w, .45, G0), W(paint), .02)
    boxab((.05, -.02, -.02), (w - .05, .5, .12), M(C['concrete2'], .9), .01)
    if interior: interior_box(.28, w - .28, 0, G0 - .3, .3, 2.4, wall=wallin, floor=floor)
    gan('gan_bang_doc', (w - .14, -.3, 2.6)); gan('gan_bang_ngang', (w / 2, -.3, G0 + .2))
    gan('gan_so_nha', (.14, -.02, 2.3)); gan('gan_dong_ho_nuoc', (.4, -.05, .3))

def simple_bike(loc, rot=0.0, col='#C8412F'):
    """Xe máy rút gọn đậu trong nhà (khung, 2 bánh, yên), ~150 tam giác."""
    g = group('xe', loc, rot)
    with at(g):
        for x in (-.62, .6): cyl(.3, .1, (x, 0, .3), M('#232323', .8), rot=(math.pi / 2, 0, 0), n=14, bv=0)
        box((.75, .26, .32), (-.22, 0, .66), M(col, .35, coat=.5), .08)
        box((.62, .25, .09), (-.25, 0, .86), M('#2A2A2A', .6), .03)
        box((.15, .15, .75), (.45, 0, .7), M(col, .35, coat=.5), .04, rot=(0, -.4, 0))
        cyl(.016, .6, (.3, 0, 1.06), M(C['steel'], .3, .9), rot=(math.pi / 2, 0, 0), n=6, bv=0)
    return g

# ---------------------------------------------------------------- 8 kiểu trệt
def tret_nha_o(w, paint, seed=1):
    ground_base(w, paint)
    folding_gate(.35, w - .35, 0, G0 - .4, .22)
    simple_bike((w / 2, 1.5, 0), math.radians(90), '#3A6EA5')
    boxab((w / 2 - .5, 2.6, 1.2), (w / 2 + .5, 2.68, 1.9), M('#A8322A', .6), .01)        # bàn thờ treo tường
    boxab((w / 2 - .55, 2.45, 1.15), (w / 2 + .55, 2.68, 1.22), M(C['wood'], .7), .01)
    ball(.05, (w / 2 - .3, 2.55, 1.3), M('#FF6040', .3, emit=1.5 if NIGHT[0] else .6))
    boxab((.45, .45, 0), (.95, .75, .5), M(C['wood2'], .8), .01)                        # kệ dép
    for i in range(4): box((.12, .22, .05), (.55 + i * .12, .6, .52), M(['#C8412F', '#3A6EA5', '#F2B33D', '#222222'][i], .7), .005)
    boxab((w - .26, -.08, 1.3), (w - .06, -.0, 1.6), M('#B4553A', .6), .01)               # hộp thư

def tret_tap_hoa(w, paint, seed=2, name='TẠP HÓA CÔ ÚT', sub='bánh kẹo · nước ngọt'):
    ground_base(w, paint)
    rolling_shutter(.35, w - .35, 0, G0 - .4, .2, open_frac=.9)
    ke_tap_hoa((w / 2, 2.35, 0), w=min(2.6, w - 1.0), h=2.0, seed=seed)
    boxab((w - 1.25, 1.2, 0), (w - .35, 1.9, 1.9), M('#C8412F', .5, coat=.3), .03)          # tủ mát
    boxab((w - 1.18, 1.17, .15), (w - .42, 1.2, 1.75), M('#CFE8EA', .05, alpha=.4), .005)
    boxab((.4, .55, 0), (min(2.0, w - 1.5), 1.1, .95), M(C['wood2'], .7), .02)              # quầy kính
    boxab((.4, .53, .5), (min(2.0, w - 1.5), .56, .9), M('#CFE8EA', .05, alpha=.4), .005)
    rnd = random.Random(seed)
    for k in range(int((w - 1) / .5)):                                                    # dây bánh snack treo
        x = .5 + k * .5
        for j in range(4): box((.16, .03, .2), (x, .08, 2.7 - j * .24), M(rnd.choice(['#F2B33D', '#C8412F', '#3A6EA5', '#3F8A5C']), .6), .005)
    if not GAME: bang_hieu(name, sub, w); awning(.3, w - .3, 2.45, -.1, depth=1.0, stripes=('#3F8A5C', '#F1ECE2'))

def tret_quan_pho(w, paint, seed=3, name='PHỞ BÀ TÁM', sub='phở bò · hủ tiếu'):
    ground_base(w, paint, wallin='#7E6A55')
    gg = group('xe_pho', (w * .3, -.25, 0))
    with at(gg):   # tủ phở inox + nồi nước lèo
        box((1.4, .6, .85), (0, 0, .43), M(C['steel'], .35, .8), .03)
        box((1.4, .6, .45), (0, 0, 1.08), M('#CFE8EA', .05, alpha=.35), .01)
        cyl(.28, .5, (.42, .02, 1.12), M(C['steel'], .3, .9), n=20, bv=.02)
        text('PHỞ', .16, (-.2, -.31, .5), M('#C8412F', .5), extrude=.006)
        for i in range(3): box((.18, .1, .04), (-.4 + i * .22, 0, .9), M('#F1ECE2', .7), .005)
    for i, x in enumerate((w * .55, w * .8)):
        if x > w - .5: continue
        ban_nhua((x, 1.4, 0), col='#E9E2D2'); ghe_nhua((x, .95, 0), C['plastic_red'], low=False); ghe_nhua((x, 1.85, 0), C['plastic_blue'], low=False)
    if not GAME: corrugated(w + .3, 1.5, M(C['ton_red'], .5, .4), (w / 2, -.8, 2.35), rot=(.22, 0, 0), period=.2, amp=.025)  # mái hiên tôn
    if not GAME: bang_hieu(name, sub, w)

def tret_sua_dt(w, paint, seed=4, name='SỬA ĐIỆN THOẠI TUẤN', sub='ép kính · thay pin'):
    ground_base(w, paint, wallin='#5F6A70', floor='#B9B3A6')
    rolling_shutter(.35, w - .35, 0, G0 - .4, .2, open_frac=.85, col=C['shutter2'])
    boxab((.5, .4, 0), (w - .5, .9, .9), M('#2457A0', .5), .02)                                  # tủ kính bày điện thoại
    boxab((.5, .38, .9), (w - .5, .9, 1.2), M('#CFE8EA', .05, alpha=.35), .005)
    for i in range(int((w - 1.2) / .25)): box((.1, .02, .18), (.7 + i * .25, .65, 1.02), M('#1E2424', .2), .005)
    for i in range(3): boxab((.6 + i * (w - 1.2) / 3, 2.6, 1.3), (.6 + (i + .85) * (w - 1.2) / 3, 2.66, 2.5),
                             M(['#F2B33D', '#C8412F', '#77AD9C'][i], .6), .005)                   # áp phích
    ghe_nhua((w / 2, 1.3, 0), C['plastic_blue'], low=False)
    if not GAME: bang_hieu(name, sub, w)

def tret_tiem_may(w, paint, seed=5, name='TIỆM MAY HỒNG NHUNG', sub='may đo · sửa đồ'):
    ground_base(w, paint, wallin='#8A6E6A')
    folding_gate(w - 1.1, w - .35, 0, G0 - .4, .22)                                                # cửa kéo xếp gọn một bên
    for k, x in enumerate((.8, 1.7)):                                                              # ma-nơ-canh
        cyl(.02, .9, (x, .7, .45), M(C['wood'], .6), n=6, bv=0)
        ball(.24, (x, .7, 1.25), M(['#D2368A', '#3A6EA5'][k], .8, sheen=.6), (1, .75, 1.5))
        cyl(.16, .05, (x, .7, .02), M(C['wood'], .6), n=12, bv=0)
    for i in range(6): cyl(.08, .9, (.7 + i * .2, 2.3, 2.0), M(['#C8412F', '#F2B33D', '#77AD9C', '#3A6EA5', '#E9E2D2', '#D7A9C4'][i], .8, sheen=.5), rot=(0, 0, 0), n=10)
    boxab((.5, 2.1, 1.5), (min(2.0, w - 1.3), 2.6, 1.55), M(C['wood2'], .7), .005)
    boxab((w - 2.2 if w > 3.6 else .6, 1.2, .72), (w - 1.2 if w > 3.6 else 1.6, 1.8, .78), M(C['wood2'], .7), .01)   # bàn máy may
    box((.4, .2, .3), (w - 1.7 if w > 3.6 else 1.1, 1.5, .93), M('#222222', .4), .03)
    if not GAME: bang_hieu(name, sub, w)

def tret_tiem_thuoc(w, paint, seed=6, name='NHÀ THUỐC TÂM AN', sub='thuốc tây · y cụ'):
    ground_base(w, paint, wallin='#E9E6DE', floor='#D6D0C2')
    al = M('#B9C1C3', .3, .7)
    for x in np.linspace(.3, w - .3, max(3, int(w / 1.1)) + 1): boxab((x - .03, .18, 0), (x + .03, .24, G0 - .4), al, .005)
    boxab((.3, .18, G0 - .46), (w - .3, .24, G0 - .4), al, .005)
    boxab((.3, .2, .05), (w - .3, .22, G0 - .46), M('#D9EEF0', .05, alpha=.25), 0)            # kính
    for k in range(4): boxab((.4, 2.25, .3 + k * .55), (w - .4, 2.6, .34 + k * .55), M('#FFFFFF', .5), .005)
    rnd = random.Random(seed)
    for k in range(4):
        for i in range(int((w - .9) / (.14 if not LITE else .42))): box((.1 if not LITE else .38, .2, .14), (.5 + i * (.14 if not LITE else .42), 2.45, .42 + k * .55), M(rnd.choice(['#FFFFFF', '#3F8A5C', '#2457A0', '#F2B33D', '#C8412F']), .5), .004)
    boxab((.6, .6, 0), (w - .6, 1.0, 1.0), M('#FFFFFF', .5), .02)
    if not GAME: bang_hieu(name, sub, w)

def tret_gui_xe(w, paint, seed=7, name='GIỮ XE', sub='ngày · đêm'):
    ground_base(w, paint, wallin='#7E7A70', floor='#8F8B80')
    rolling_shutter(.35, w - .35, 0, G0 - .4, .2, open_frac=.95, col=C['shutter2'])
    cols = ['#C8412F', '#2E2E2E', '#3A6EA5', '#E9E2D2', '#C8412F', '#F2B33D']
    n = max(2, int((w - .6) / .7))
    for i in range(n): simple_bike((.65 + i * .7, 1.5, 0), math.radians(78), cols[i % len(cols)])
    boxab((w - 1.0, .3, 0), (w - .35, .8, .8), M(C['wood2'], .7), .02)                         # bàn vé
    box((.3, .2, .05), (w - .7, .5, .83), M('#F2B33D', .7), .005)
    if not GAME: bang_hieu(name, sub, w)

def tret_hot_toc(w, paint, seed=8, name='HỚT TÓC ANH BA', sub='cắt · gội · cạo mặt'):
    ground_base(w, paint, wallin='#7A8A86')
    folding_gate(.35, 1.0, 0, G0 - .4, .22)
    boxab((w - 1.8, 2.6, .9), (w - .6, 2.66, 2.2), M('#DDEBEE', .05, metal=.9), .005)            # gương
    boxab((w - 1.85, 2.5, .85), (w - .55, 2.66, .9), M(C['wood'], .7), .005)
    gg = group('ghe_cat', (w - 1.2, 1.9, 0))
    with at(gg):
        cyl(.18, .1, (0, 0, .05), M(C['steel'], .3, .9), n=14); cyl(.04, .4, (0, 0, .3), M(C['steel'], .3, .9), n=8)
        box((.5, .5, .12), (0, 0, .55), M('#8A2A1E', .5), .04); box((.5, .1, .6), (0, .25, .9), M('#8A2A1E', .5), .04)
    # cột xoay sọc đỏ xanh trắng
    cyl(.09, .9, (.14, -.15, 1.9), M('#F1ECE2', .3), n=14, bv=.01)
    for i in range(6):
        torus(.092, .018, (.14, -.15, 1.55 + i * .14), M('#C8412F' if i % 2 else '#2457A0', .4), rot=(.35, 0, 0), n=14 if not LITE else 8, m=4 if not LITE else 3)
    ball(.1, (.14, -.15, 2.38), M('#F1ECE2', .3)); ball(.1, (.14, -.15, 1.42), M('#F1ECE2', .3))
    if not GAME: bang_hieu(name, sub, w)

TRET = dict(nha_o=tret_nha_o, tap_hoa=tret_tap_hoa, quan_pho=tret_quan_pho, sua_dt=tret_sua_dt,
            tiem_may=tret_tiem_may, tiem_thuoc=tret_tiem_thuoc, gui_xe=tret_gui_xe, hot_toc=tret_hot_toc)
TRET_TEN = dict(nha_o='Nhà ở cửa sắt kéo', tap_hoa='Tạp hóa', quan_pho='Quán phở', sua_dt='Sửa điện thoại',
                tiem_may='Tiệm may', tiem_thuoc='Tiệm thuốc', gui_xe='Chỗ gửi xe', hot_toc='Hớt tóc')
# bảng hiệu chữ tạo sẵn: 3 tên cho mỗi kiểu tiệm (tên thuần Việt, không thương hiệu thật)
BANG = dict(tap_hoa=[('TẠP HÓA CÔ ÚT', 'bánh kẹo · nước ngọt'), ('TẠP HÓA THU HÀ', 'gạo · mắm · dầu ăn'), ('TẠP HÓA BẢY HIỀN', 'nước đá · ve chai')],
            quan_pho=[('PHỞ BÀ TÁM', 'phở bò · hủ tiếu'), ('PHỞ GÁNH CHÚ SÁU', 'phở gà · bún bò'), ('HỦ TIẾU MÌ NĂM CƯỜNG', 'hủ tiếu nam vang')],
            sua_dt=[('SỬA ĐIỆN THOẠI TUẤN', 'ép kính · thay pin'), ('ĐIỆN THOẠI KIM NGÂN', 'sim · thẻ cào · phụ kiện'), ('SỬA MÁY MINH', 'điện thoại · máy tính')],
            tiem_may=[('TIỆM MAY HỒNG NHUNG', 'may đo · sửa đồ'), ('NHÀ MAY THANH THẢO', 'áo dài · đồng phục'), ('TIỆM MAY BÉ TƯ', 'lên lai · thay dây kéo')],
            tiem_thuoc=[('NHÀ THUỐC TÂM AN', 'thuốc tây · y cụ'), ('QUẦY THUỐC HẠNH PHÚC', 'thuốc tây · sữa'), ('NHÀ THUỐC MINH CHÂU', 'đo huyết áp miễn phí')],
            gui_xe=[('GIỮ XE', 'ngày · đêm'), ('GIỮ XE THÁNG', 'an toàn · có mái che'), ('GỬI XE', '24/24')],
            hot_toc=[('HỚT TÓC ANH BA', 'cắt · gội · cạo mặt'), ('SALON TÓC MỸ LINH', 'uốn · nhuộm · duỗi'), ('HỚT TÓC BÌNH DÂN', 'cắt tóc nam')])

# ---------------------------------------------------------------- 6 kiểu lầu
def lau_base(w, z, paint, y0=.3):
    body_slice(w, z, z + F, paint, y0)
    piers(w, z, z + F, paint)
    slab_lip(w, z)
    gan('gan_may_lanh_1', (w - .7, -.05, z + 2.4)); gan('gan_chau_1', (.5, -.1, z + .1)); gan('gan_long_chim', (w / 2, -.4, z + 2.7))

def french_doors(w, z, y=.28, col=None, seed=0):
    dw = min(2.4, w - 1.0)
    boxab((w / 2 - dw / 2 - .1, y, z + .1), (w / 2 + dw / 2 + .1, y + .04, z + 2.4), M(TRIM, .7), .01)
    for k in range(4):
        xk = w / 2 - dw / 2 + (k + .5) * dw / 4
        if k in (1, 2) and NIGHT[0]: boxab((xk - dw / 8 + .02, y - .03, z + .15), (xk + dw / 8 - .02, y + .01, z + 2.3), glass(seed + k), 0); continue
        boxab((xk - dw / 8 + .02, y - .03, z + .15), (xk + dw / 8 - .02, y + .01, z + 2.3), M(col or C['shutter'], .6), .01)
        for j in range(14): box((dw / 4 - .1, .03, .01), (xk, y - .04, z + .3 + j * .14), M('#1F2A2A', .7), 0, rot=(.6, 0, 0))

def lau_ban_cong(w, z, paint, seed=1):
    lau_base(w, z, paint)
    boxab((.05, -1.0, z - .05), (w - .05, .3, z + .1), M(C['concrete'], .9), .02)
    railing(.12, w - .12, -.95, z + .1, mat=M(C['iron'], .5, .6))
    for sx in (.12, w - .16): boxab((sx, -1.0, z + .1), (sx + .04, -.96, z + 1.1), M(C['iron'], .5, .6), 0)
    french_doors(w, z, col=C['shutter'] if seed % 2 else '#6E8F5E', seed=seed)
    gan('gan_chau_2', (w - .45, -.65, z + .1)); gan('gan_day_phoi', (w / 2, -.9, z + 2.5))

def lau_cua_chop(w, z, paint, seed=2):
    lau_base(w, z, paint)
    n = 2 if w >= 4.4 else 1; ww = min(1.3, (w - 1.2) / n - .3)
    for i in range(n):
        x = w * (i + 1) / (n + 1)
        louver_window(x, z + .8, ww, 1.5, .3, SON.get(paint, paint), '#6E8F5E' if seed % 2 else C['shutter'], open_=.5 + .2 * i)
        if NIGHT[0]: boxab((x - ww / 2, .27, z + .8), (x + ww / 2, .29, z + 2.3), glass(seed * 3 + i), 0)

def lau_lo_gia(w, z, paint, seed=3):
    body_slice(w, z, z + F, paint, y0=1.4)                                                   # tường lùi vào 1,4 m
    piers(w, z, z + F, paint, d=1.45); slab_lip(w, z)
    boxab((.28, .0, z + 2.55), (w - .28, 1.45, z + F), W(paint), .02)                         # dầm trên lô gia
    boxab((.2, .3, z + .05), (w - .2, 1.45, z + .1), M('#B9A58A', .85), .01)                  # sàn gạch
    boxab((.28, .0, z + .1), (w - .28, .3, z + .9), W(paint), .02)                            # lan can xây + bồn cây
    boxab((.24, -.04, z + .86), (w - .24, .34, z + .95), M(TRIM, .8), .015)
    rnd = random.Random(seed)
    for i in range(int((w - .6) / .45)):
        ball(rnd.uniform(.16, .24), (.5 + i * .45, .15, z + 1.05 + rnd.uniform(0, .12)), M(C['leaf'] if i % 2 else C['leaf2'], .85, sheen=.3), sub=1)
    boug_cascade(.4, min(w - .4, 2.0), .0, z + 1.0, drop=1.0, seed=seed) if not LITE else None
    if LITE:
        for i in range(5): ball(.1, (.5 + i * .3, -.05, z + .8 - (i % 3) * .2), M(C['boug'], .85), sub=1)
    boxab((w / 2 - .7, 1.38, z + .1), (w / 2 + .7, 1.42, z + 2.3), M(TRIM, .7), .01)          # cửa trong lô gia
    boxab((w / 2 - .62, 1.36, z + .18), (w / 2 + .62, 1.39, z + 2.22), glass(seed + 7), 0)
    plant_pot((w - .6, .9, z + .1), kind='palm', s=.7) if not LITE else None
    gan('gan_may_lanh_1', (w - .7, 1.3, z + 2.3)); gan('gan_day_phoi', (w / 2, .9, z + 2.4)); gan('gan_long_chim', (.8, .6, z + 2.5))

def lau_chuong_cop(w, z, paint, seed=4):
    lau_base(w, z, paint)
    ww = min(1.6, w - 1.2)
    louver_window(w / 2, z + .8, ww, 1.5, .3, SON.get(paint, paint), C['shutter'])
    if NIGHT[0]: boxab((w / 2 - ww / 2, .27, z + .8), (w / 2 + ww / 2, .29, z + 2.3), glass(seed), 0)
    m = M(C['iron'], .5, .6); cw = min(2.2, w - .7)
    for xx in np.linspace(w / 2 - cw / 2, w / 2 + cw / 2, 12): boxab((xx - .012, -.55, z + .5), (xx + .012, -.52, z + 2.6), m, 0)
    for zz in (z + .5, z + 1.55, z + 2.6): boxab((w / 2 - cw / 2, -.55, zz - .02), (w / 2 + cw / 2, .3, zz + .02), m, 0)
    for xx in (w / 2 - cw / 2, w / 2 + cw / 2):
        for zz in (z + .5, z + 2.6): boxab((xx - .02, -.55, zz - .02), (xx + .02, .3, zz + .02), m, 0)
        boxab((xx - .012, -.55, z + .5), (xx + .012, -.52, z + 2.6), m, 0)
    boxab((w / 2 - cw / 2, -.55, z + 2.6), (w / 2 + cw / 2, .3, z + 2.64), M(C['ton_blue'], .5, .4), 0)   # tấm che trên
    gan('gan_chau_1', (w / 2 - .5, -.25, z + .52))

def lau_kinh_lua(w, z, paint, seed=5):
    lau_base(w, z, paint)
    boxab((.05, -.6, z - .05), (w - .05, .3, z + .1), M(C['concrete'], .9), .02)
    st = M(C['steel'], .3, .85)
    boxab((.12, -.58, z + 1.0), (w - .12, -.55, z + 1.05), st, .005)                         # lan can inox ống
    for x in np.linspace(.15, w - .15, max(3, int(w / 1.0))): boxab((x - .015, -.58, z + .1), (x + .015, -.55, z + 1.0), st, 0)
    boxab((.15, -.58, z + .12), (w - .15, -.565, z + .95), M('#BFD8DE', .05, alpha=.3), 0)   # kính cường lực
    al = M('#D9DDDD', .3, .6); n = 3 if w >= 4.4 else 2; x0, x1 = .4, w - .4
    boxab((x0 - .05, .26, z + .1), (x1 + .05, .3, z + 2.55), al, .005)
    for i in range(n + 1): boxab((x0 + i * (x1 - x0) / n - .03, .22, z + .1), (x0 + i * (x1 - x0) / n + .03, .27, z + 2.5), al, .005)
    for i in range(n):
        xa = x0 + i * (x1 - x0) / n + .03; xb = x0 + (i + 1) * (x1 - x0) / n - .03
        boxab((xa, .23, z + .15), (xb, .25, z + 2.45), glass(seed + i) if NIGHT[0] else M('#5E8A9C', .08, metal=.3), 0)
    boxab((.3, .2, z + 2.6), (w - .3, .3, z + 2.85), M('#7E8B88', .5), .01)                   # hộp rèm
    gan('gan_chau_2', (.5, -.3, z + .1))

def lau_tuong_kin(w, z, paint, seed=6):
    lau_base(w, z, paint, y0=.25)
    bm = M('#E6DCC4', .85); nx = int((min(w - 1.2, 2.4)) / .4); x0 = .6
    for i in range(nx):                                                                     # ô gạch bông gió
        for j in range(4):
            cx = x0 + .2 + i * .4; cz = z + .9 + .2 + j * .4
            boxab((cx - .19, .2, cz - .19), (cx + .19, .25, cz + .19), M('#3A3530', .9), 0)
            if LITE: boxab((cx - .02, .18, cz - .19), (cx + .02, .22, cz + .19), bm, 0)
            else: torus(.13, .03, (cx, .2, cz), bm, rot=(math.pi / 2, 0, 0), n=10, m=4)
            boxab((cx - .19, .18, cz - .02), (cx + .19, .22, cz + .02), bm, 0)
    wx = x0 + nx * .4 + .5
    if wx + .5 < w - .3:                                                                    # cửa sổ nhỏ
        boxab((wx - .05, .2, z + 1.25), (wx + .65, .26, z + 2.05), M(TRIM, .7), .01)
        boxab((wx, .18, z + 1.3), (wx + .6, .21, z + 2.0), glass(seed), 0)
        for xx in np.linspace(wx + .05, wx + .55, 5): boxab((xx - .01, .14, z + 1.3), (xx + .01, .17, z + 2.0), M(C['iron'], .5, .6), 0)
    gan('gan_may_lanh_1', (w - .7, .05, z + 1.0))

LAU = dict(ban_cong=lau_ban_cong, cua_chop=lau_cua_chop, lo_gia=lau_lo_gia, chuong_cop=lau_chuong_cop, kinh_lua=lau_kinh_lua, tuong_kin=lau_tuong_kin)
LAU_TEN = dict(ban_cong='Ban công sắt hoa', cua_chop='Cửa chớp gỗ', lo_gia='Lô gia có cây', chuong_cop='Chuồng cọp sắt', kinh_lua='Cửa kính lùa', tuong_kin='Tường kín ô gió')

# ---------------------------------------------------------------- 5 kiểu mái (mỗi kiểu trả về profile mặt mái để SanThuong đo)
def parapet(w, z, paint, h=.9, sides=True):
    segs = [((0, -.0), (w, .15))] + ([((0, D - .15), (w, D)), ((0, 0), (.15, D)), ((w - .15, 0), (w, D))] if sides else [])
    for (a, b) in segs:
        boxab((a[0], a[1], z), (b[0], b[1], z + h), W(paint), .02)
        boxab((a[0] - .03, a[1] - .03, z + h), (b[0] + .03, b[1] + .03, z + h + .1), M(TRIM, .8), .015)

def mai_ton(w, z, paint, seed=1):
    boxab((0, 0, z), (w, D, z + .12), M(C['concrete'], .9), .01)
    boxab((0, -.0, z), (w, .3, z + .6), W(paint), .02)                                    # tường đầu hồi phía trước
    boxab((-.03, -.03, z + .6), (w + .03, .33, z + .7), M(TRIM, .8), .015)
    zf, zb = z + .75, z + .3; ang = math.atan2(zf - zb, D)                                # dốc từ trước ra sau
    corrugated(w + .1, D + .2, M(C['ton_blue'] if seed % 2 else C['ton_red'], .45, .5), (w / 2, D / 2 + .1, (zf + zb) / 2), rot=(-ang, 0, 0), period=.2, amp=.025)
    for x in (.05, w / 2, w - .05):
        mesh_obj('ke', [(x - .03, .3, z + .12), (x + .03, .3, z + .12), (x + .03, .3, zf - .05), (x - .03, .3, zf - .05),
                        (x - .03, D, z + .12), (x + .03, D, z + .12), (x + .03, D, zb - .05), (x - .03, D, zb - .05)],
                 [(0, 1, 2, 3), (4, 7, 6, 5), (0, 4, 5, 1), (3, 2, 6, 7), (0, 3, 7, 4), (1, 5, 6, 2)], M(C['iron'], .5, .6))
    return dict(kieu='doc', mat=[[.3, zf - z + .03], [D, zb - z + .03]], ghi='tôn dốc 4°, mép trước cao hơn; Bơ đi được nhưng trượt nhẹ (tuỳ game)',
                vat_can=[[0, w, 0, .3, .7]])

def mai_san_thuong(w, z, paint, seed=2):
    boxab((0, 0, z), (w, D, z + .15), M(C['concrete'], .9), .01)
    parapet(w, z + .15, paint)
    water_tank((w - 1.0, D - 1.3, z + .15), horizontal=False)
    if w > 3.5: plant_pot((.6, .8, z + .15), kind='bush', s=.8)
    cyl(.05, 1.0, (.3, D - .3, z + .6), M('#E9E6DE', .5), n=8, bv=0)                     # ống thoát nước
    gan('gan_day_phoi', (w / 2 - .6, D * .5, z + 1.8)); gan('gan_anten', (.6, D - 1.0, z + .15))
    return dict(kieu='bang', mat=[[0, .15], [D, .15]], ghi='sân thượng phẳng, tường lửng 0,9 m (Bơ nhảy qua được: 1,0 m < 1,3 m)',
                vat_can=[[0, w, 0, .15, 1.15], [w - 1.5, w - .5, D - 1.8, D - .8, 1.6]])

def mai_ngoi(w, z, paint, seed=3):
    boxab((-.05, -.05, z), (w + .05, D + .05, z + .25), M(TRIM, .8), .02)
    roof_ngoi(w, D, z + .25, ridge_h=1.7)
    return dict(kieu='ngoi', mat=[[-.35, .25], [D / 2, 1.95], [D + .35, .25]], ghi='ngói hai mái, nóc dọc mặt tiền ở giữa sâu; dốc 25°',
                vat_can=[])

def mai_tum(w, z, paint, seed=4):
    boxab((0, 0, z), (w, D, z + .15), M(C['concrete'], .9), .01)
    parapet(w, z + .15, paint, h=1.0)
    hw = min(2.4, w - .3)
    boxab((w - hw - .15, D - 3.0, z + .15), (w - .15, D - .15, z + 2.6), W(paint), .02)
    boxab((w - hw - .3, D - 3.15, z + 2.6), (w - .05, D - .05, z + 2.75), M(C['concrete'], .9), .02)
    boxab((w - hw + .3, D - 3.03, z + .2), (w - hw + 1.1, D - 2.99, z + 2.2), M(C['wood'], .7), .01)
    boxab((w - .9, D - 3.03, z + 1.4), (w - .45, D - 2.99, z + 1.9), glass(seed), 0)
    antenna((w - 1.0, D - 1.5, z + 2.75))
    plant_pot((.5, .6, z + .15), kind='boug', s=.8) if not LITE else None
    return dict(kieu='bang', mat=[[0, .15], [D, .15]], ghi='sân thượng + tum cầu thang 2,45 m ở sau (mái tum phẳng, leo được từ bồn/ghế)',
                vat_can=[[0, w, 0, .15, 1.25], [w - hw - .15, w - .15, D - 3.0, D - .15, 2.75]])

def mai_luoi(w, z, paint, seed=5):
    boxab((0, 0, z), (w, D, z + .15), M(C['concrete'], .9), .01)
    parapet(w, z + .15, paint, h=.8)
    st = M(C['steel'], .4, .7); y0, y1 = 1.0, D - .6
    for x in (.3, w - .3):
        for y in (y0, y1): cyl(.03, 2.3, (x, y, z + 1.3), st, n=8, bv=0)
        cyl(.025, y1 - y0, (x, (y0 + y1) / 2, z + 2.45), st, rot=(math.pi / 2, 0, 0), n=6, bv=0)
    for y in (y0, (y0 + y1) / 2, y1): cyl(.025, w - .6, (w / 2, y, z + 2.45), st, rot=(0, math.pi / 2, 0), n=6, bv=0)
    net = M('#3E8A5A', .9, alpha=.75)
    boxab((.3, y0, z + 2.47), (w - .3, (y0 + y1) / 2 + .8, z + 2.49), net, 0)                # lưới che nắng một nửa
    laundry(.5, w - .5, (y0 + y1) / 2 + 1.3, z + 1.9, seed)                                # dây phơi đúc liền (nhận diện kiểu)
    for i in range(3): plant_pot((.6 + i * .7, y0 + .3, z + .15), kind='bush', s=.6) if not LITE else ball(.22, (.6 + i * .7, y0 + .3, z + .4), M(C['leaf'], .85), sub=1)
    return dict(kieu='bang', mat=[[0, .15], [D, .15]], ghi='sân thượng có giàn lưới 2,45 m; mái lưới không đứng được (rơi xuyên)',
                vat_can=[[0, w, 0, .15, .95]])

MAI = dict(ton=mai_ton, san_thuong=mai_san_thuong, ngoi=mai_ngoi, tum=mai_tum, luoi=mai_luoi)
MAI_TEN = dict(ton='Tôn dốc', san_thuong='Sân thượng bồn inox', ngoi='Ngói đỏ', tum='Tum cầu thang', luoi='Mái lưới có dây phơi')

# ---------------------------------------------------------------- ráp một căn
def nha(name, spec, loc=(0, 0, 0), rot=0.0, explode=0.0):
    """spec: w, tret, lau [list], mai, son, bang (chỉ số tên bảng hiệu), seed."""
    w = spec['w']; paint = spec['son']; seed = spec.get('seed', 1)
    g = group(name, loc, rot); prof = None
    with at(g):
        gt = group('tret', (0, 0, 0))
        with at(gt):
            fn = TRET[spec['tret']]
            if spec['tret'] in BANG:
                nm, sb = BANG[spec['tret']][spec.get('bang', 0) % 3]; fn(w, paint, seed, nm, sb)
            else: fn(w, paint, seed)
        for i, k in enumerate(spec['lau']):
            gl = group(f'lau{i + 1}', (0, 0, explode * (i + 1)))
            with at(gl): LAU[k](w, G0 + F * i, paint, seed + i)
        top = G0 + F * len(spec['lau'])
        gm = group('mai', (0, 0, explode * (len(spec['lau']) + 1)))
        with at(gm): prof = MAI[spec['mai']](w, top, paint, seed)
    return g, prof, top

# ---------------------------------------------------------------- bản xa cho vành phố (P1)
def nha_xa(name, spec, loc=(0, 0, 0), depth=8.0, front_only=False):
    """~80–150 tam giác: hộp thân, mặt tiền phẳng có ô cửa tối, gờ sàn, mái đơn giản. Không đổ bóng."""
    w = spec['w']; n = len(spec['lau']); top = G0 + F * n; wall = W(spec['son'])
    d = 3.0 if front_only else depth
    g = group(name, loc)
    with at(g):
        boxab((0, 0, 0), (w, d, top), wall, 0)
        boxab((.3, -.02, .0), (w - .3, .0, G0 - .4), M('#3B3A36', .8), 0)                    # ô trệt tối
        boxab((.2, -.1, G0 - .7), (w - .2, -.02, G0 - .3), M(['#C8412F', '#2457A0', '#F2B33D', '#3F8A5C'][spec.get('seed', 1) % 4], .6), 0)
        for i, k in enumerate(spec['lau']):
            z = G0 + F * i
            boxab((-.02, -.15, z - .08), (w + .02, .0, z + .08), M(TRIM, .8), 0)
            if k in ('ban_cong', 'kinh_lua'): boxab((.1, -.8, z), (w - .1, .0, z + .9), M(C['iron'] if k == 'ban_cong' else '#BFD8DE', .6), 0)
            ww = w - 1.2 if k != 'tuong_kin' else .6
            boxab((w / 2 - ww / 2, -.02, z + .5), (w / 2 + ww / 2, .0, z + 2.4), glass(i + spec.get('seed', 1)) if NIGHT[0] else M('#3A4644', .5), 0)
        mk = spec['mai']
        if mk == 'ngoi':
            mesh_obj('mai', [(0, 0, top), (w, 0, top), (w, d, top), (0, d, top), (0, d / 2, top + 1.7), (w, d / 2, top + 1.7)],
                     [(0, 1, 5, 4), (2, 3, 4, 5), (0, 4, 3), (1, 2, 5)], M(C['tile'], .75))
        elif mk == 'ton':
            mesh_obj('mai', [(0, 0, top + .7), (w, 0, top + .7), (w, d, top + .3), (0, d, top + .3)], [(0, 1, 2, 3)], M(C['ton_blue'], .5, .4))
        else:
            boxab((0, 0, top), (w, d, top + .9), wall, 0)
            boxab((.15, .15, top + .15), (w - .15, d - .15, top + .91), M(C['concrete'], .9), 0)
            if mk == 'tum': boxab((w - 2.2, d - 2.8, top), (w - .15, d - .15, top + 2.6), wall, 0)
            if mk == 'san_thuong': cyl(.45, 1.3, (w - 1.0, d - 1.3, top + .8), M(C['steel'], .3, .9), n=8, bv=0)
    return g

# ---------------------------------------------------------------- 5 nhà mốc
def nha_dang_xay(name='nha_dang_xay', loc=(0, 0, 0)):
    """Nhà ống 6 m đang đổ sàn tầng 3: khung bê tông, tường gạch dở, giàn giáo trước mặt có ván so le leo được."""
    w = 6.0; g = group(name, loc)
    conc = M('#B5AFA3', .95); brick = M('#C0613E', .9); brick2 = M('#A85434', .9); st = M('#5E7A8A', .4, .7); wood = M('#C29A5E', .85)
    slabs = (0, 3.4, 6.5, 9.6)
    with at(g):
        for x in (0, w / 2 - .12, w - .25):
            for y in (0, D / 2, D - .25):
                boxab((x, y, 0), (x + .25, y + .25, 9.6), conc, .01)
                for k in range(3): cyl(.008, .8, (x + .07 + k * .05, y + .12, 9.6 + .4), M('#6B4A3A', .6, .5), n=4, bv=0)   # thép chờ
        for z in slabs[1:]: boxab((-.05, -.05, z - .2), (w + .05, D + .05, z), conc, .01)
        boxab((0, -.05, -.02), (w, D, .1), conc, .01)
        rnd = random.Random(3)
        # tường gạch: trệt kín hai bên, lầu 1 xây dở, lầu 2 trống
        for sx in (0, w - .2):
            for row in range(int(3.2 / .2)):
                boxab((sx, .25, .1 + row * .2), (sx + .2, D - .25, .1 + row * .2 + .19), brick if row % 2 else brick2, 0)
            for row in range(int(rnd.uniform(1.4, 2.4) / .2)):
                boxab((sx, .25, 3.4 + row * .2), (sx + .2, D * .7, 3.4 + row * .2 + .19), brick if row % 2 else brick2, 0)
        boxab((.25, D - .2, 0), (w - .25, D, 3.2), brick, 0)
        # giàn giáo phía trước: y -1.5..-.3, 3 nhịp 2 m, ván mỗi 1,1 m so le trái/phải -> bậc thang cho Bơ
        bays = (0, 2.0, 4.0, 6.0); yf, yb = -1.5, -.3
        for x in bays:
            for y in (yf, yb): cyl(.025, 10.4, (x, y, 5.2), st, n=8, bv=0)
        for zz in np.arange(1.1, 10.4, 1.1):
            for y in (yf, yb): cyl(.02, 6.0, (3.0, y, zz), st, rot=(0, math.pi / 2, 0), n=6, bv=0)
        for i in range(9):
            for x in bays[:-1]: curve([(x, yf, 1.1 * i), (x + 2.0, yf, 1.1 * (i + 1))], .012, st)   # giằng chéo
        planks = []
        for i, zz in enumerate(np.arange(1.1, 10.0, 1.1)):
            b = (0, 1, 2, 1)[i % 4]                                                                 # mỗi ván lệch sang nhịp bên cạnh, không ván nào nằm ngay trên ván trước
            x0 = bays[b] + .05; x1 = bays[b + 1] - .05
            boxab((x0, yf - .05, zz + .02), (x1, yb + .05, zz + .07), wood, .005); planks.append([round(x0, 2), round(x1, 2), round(float(zz + .07), 2)])
            for x in np.linspace(x0 + .1, x1 - .1, 4): boxab((x - .015, yf - .05, zz + .07), (x + .015, yb + .05, zz + .075), M('#A27C46', .85), 0)
        # lưới xanh che một nửa trên
        boxab((4.0, yf - .08, 5.5), (6.05, yf - .06, 10.3), M('#3E8A5A', .9, alpha=.7), 0)
        # đồ công trường dưới đất: chồng gạch (bậc đầu 0,55 m), bao xi măng, đống cát, xô
        for k in range(3):
            for j in range(4): boxab((-.9 + j * .22, -2.6 + k * .12, 0 + k * 0), (-.9 + j * .22 + .2, -2.6 + k * .12 + .1, .55), brick, 0) if k == 0 else None
        boxab((.4, -2.6, 0), (1.4, -1.9, .55), brick2, .01)
        for k in range(3): box((.6, .4, .18), (2.4, -2.3, .09 + k * .18), M('#D9D2C0', .95), .04)
        ball(1.0, (4.6, -2.6, -.05), M('#D4B47A', .95), (1.2, .8, .4), sub=2)
        cyl(.15, .3, (5.6, -1.9, .15), M('#3A3F40', .6), r2=.18, n=12)
        curve([(5.0, -.9, 10.2), (5.0, -1.0, 6.0)], .006, M('#D9C38E', .8))                          # dây ròng rọc
        cyl(.12, .25, (5.0, -1.0, 5.9), M('#3A3F40', .6), n=10)
        boxab((.6, -1.62, 2.0), (2.0, -1.56, 2.8), M('#F2B33D', .6), .01)
        text('ĐANG THI CÔNG', .14, (1.3, -1.64, 2.5), M('#222222', .5), extrude=.004)
        text('xin lỗi vì sự bất tiện', .08, (1.3, -1.64, 2.25), M('#222222', .5), extrude=.003)
    return g, dict(van=planks, buoc='1,1 m mỗi bậc (nhảy 1,3 m), ván dài 1,9 m, sâu 1,2 m', dinh=9.6)

def biet_thu_phap(name='biet_thu', loc=(0, 0, 0)):
    """Biệt thự Pháp cũ ở góc phố: hai mặt tiền (trước -y và hông +x), cửa chớp xanh, mái ngói bốn mái, cổng sắt, cây sứ."""
    w, d = 9.0, 9.5; g = group(name, loc); wall = M('#EED9A0', .88); trim = M('#F6F0E2', .8); sh = '#4E8A6A'
    H1, H2 = 3.8, 7.2
    with at(g):
        boxab((0, 0, 0), (w, d, .6), M('#B9B3A6', .9), .02)                                          # nền cao
        boxab((.15, .15, .6), (w - .15, d - .15, H2), wall, .03)
        for z in (H1, H2): boxab((0, 0, z - .15), (w, d, z + .05), trim, .03)                         # gờ phào
        for (x0, x1) in ((.15, .55), (w - .55, w - .15)):
            boxab((x0, .05, .6), (x1, .25, H2), trim, .02)
        for x in (1.8, 4.5, 7.2):                                                                   # cửa sổ mặt trước
            for z, h in ((1.4, 1.9), (H1 + .6, 1.9)):
                if x == 4.5 and z < 2: continue
                louver_window(x, z, 1.1, h, .15, '#EED9A0', sh, open_=.35)
                mesh_obj('vom', [(x - .7, .1, z + h + .1), (x + .7, .1, z + h + .1), (x, .1, z + h + .45)], [(0, 1, 2)], trim)
        # cửa chính + bậc tam cấp
        boxab((4.5 - .8, .1, .6), (4.5 + .8, .16, 3.2), trim, .01)
        for k in range(2): boxab((4.5 - .7 + k * .7, .08, .65), (4.5 - .02 + k * .7, .12, 3.1), M(sh, .6), .01)
        for k in range(3): boxab((3.5, -.35 * (k + 1), 0), (5.5, -.35 * k, .6 - k * .2), M('#B9B3A6', .9), .01)
        # ban công nhỏ lầu trên giữa, lan can con tiện
        boxab((3.4, -.9, H1 - .05), (5.6, .2, H1 + .12), trim, .02)
        for x in np.arange(3.5, 5.55, .18):
            cyl(.045, .7, (x, -.82, H1 + .47), trim, r2=.03, n=8, bv=0)
        boxab((3.4, -.9, H1 + .82), (5.6, -.74, H1 + .9), trim, .01)
        for x in (3.5, 5.5): boxab((x - .1, -.9, 0), (x + .1, -.7, H1), trim, .02)
        # mặt hông (+x) cũng là mặt tiền vì nhà ở góc
        for y in (2.2, 4.8, 7.4):
            for z, h in ((1.4, 1.9), (H1 + .6, 1.9)):
                gg = group('cua_hong', (w - .15, y, 0), rot=math.pi / 2)
                with at(gg): louver_window(0, z, 1.1, h, -.02, '#EED9A0', sh, open_=.35)
        # mái ngói bốn mái
        ov = .5; zr = H2 + .05; rh = 2.4
        V = [(-ov, -ov, zr), (w + ov, -ov, zr), (w + ov, d + ov, zr), (-ov, d + ov, zr), (2.6, d / 2, zr + rh), (w - 2.6, d / 2, zr + rh)]
        mesh_obj('mai4', V, [(0, 1, 5, 4), (2, 3, 4, 5), (1, 2, 5), (3, 0, 4)], M(C['tile'], .75))
        for (a, b) in ((V[4], V[5]), (V[0], V[4]), (V[1], V[5]), (V[2], V[5]), (V[3], V[4])):
            a = np.array(a); b = np.array(b); c = (a + b) / 2; L = np.linalg.norm(b - a); dv = (b - a) / L
            o = cyl(.09, L, tuple(c + [0, 0, .05]), M(C['tile2'], .75), n=10, bv=0)
            o.rotation_mode = 'QUATERNION'; o.rotation_quaternion = Vector((0, 0, 1)).rotation_difference(Vector(tuple(dv)))
        boxab((1.5, 6.5, zr), (2.3, 7.3, zr + 2.4), wall, .02)                                       # ống khói
        # sân + tường rào + cổng sắt (rào hai phía vì ở góc)
        yr = -3.2; xr = w + 2.6
        for (a, b) in (((-.3, yr - .2), (3.2, yr)), ((5.8, yr - .2), (xr + .2, yr)), ((xr, yr), (xr + .2, d + .3))):
            boxab((a[0], a[1], 0), (b[0], b[1], .7), wall, .02); boxab((a[0] - .03, a[1] - .03, .7), (b[0] + .03, b[1] + .03, .78), trim, .01)
            horiz = abs(b[1] - a[1]) < .5
            n = int((b[0] - a[0] if horiz else b[1] - a[1]) / .16)
            for i in range(n):
                p = (a[0] + i * .16 + .08, (a[1] + b[1]) / 2) if horiz else ((a[0] + b[0]) / 2, a[1] + i * .16 + .08)
                cyl(.012, .9, (p[0], p[1], 1.23), M(C['iron'], .5, .6), n=6, bv=0)
                ball(.025, (p[0], p[1], 1.7), M('#C9A23D', .4, .6), (1, 1, 2), sub=1)
        for x in (3.2, 5.8): boxab((x - .2, yr - .25, 0), (x + .2, yr + .05, 2.1), wall, .02); ball(.18, (x, yr - .1, 2.25), trim, sub=1)
        for k, (x0, x1) in enumerate(((3.4, 4.5), (4.5, 5.6))):                                     # cánh cổng
            for x in np.arange(x0 + .06, x1, .12): cyl(.012, 1.7, (x, yr - .1, .95), M(C['iron'], .5, .6), n=6, bv=0)
            for zz in (.15, .9, 1.75): boxab((x0, yr - .12, zz - .02), (x1, yr - .08, zz + .02), M(C['iron'], .5, .6), 0)
            torus(.25, .015, ((x0 + x1) / 2, yr - .1, 1.32), M('#C9A23D', .4, .6), rot=(math.pi / 2, 0, 0), n=16, m=4)
        boxab((4.2, yr - .26, 1.65), (4.8, yr - .22, 1.9), M('#2457A0', .6), .01)
        text('Số 1', .12, (4.5, yr - .27, 1.77), M(TRIM, .5), extrude=.003)
        # cây sứ (hoa đại) trong sân góc trái
        tm = M('#8C7A66', .9)
        curve([(1.4, -1.8, 0), (1.5, -1.8, 1.4), (1.1, -1.9, 2.4), (.6, -2.1, 3.0)], .12, tm)
        curve([(1.5, -1.8, 1.4), (2.1, -1.5, 2.6), (2.5, -1.6, 3.1)], .09, tm)
        rnd = random.Random(11)
        for (cx, cy, cz) in ((.6, -2.1, 3.1), (2.5, -1.6, 3.2), (1.6, -1.8, 3.4)):
            for i in range(7):
                ball(rnd.uniform(.25, .4), (cx + rnd.uniform(-.4, .4), cy + rnd.uniform(-.4, .4), cz + rnd.uniform(-.1, .3)), M(C['leaf'] if i % 2 else C['leaf2'], .85, sheen=.3), sub=2)
            for i in range(6): ball(.07, (cx + rnd.uniform(-.45, .45), cy + rnd.uniform(-.45, .45), cz + rnd.uniform(.15, .45)), M('#F7EEDC', .6), sub=1)
    return g, dict(the_tich=[w, d, H2 + 2.45], san_truoc=3.2, ghi='mặt trước -y và mặt hông +x đều là mặt tiền (đặt ở góc phố)')

def mieu_tho_dia(name='mieu', loc=(0, 0, 0)):
    """Miếu thổ địa nhỏ đầu hẻm: bệ gạch men, miếu mái cong, lư hương, mâm trái cây, cây bồ đề nhỏ phía sau."""
    g = group(name, loc); red = M('#B8322A', .6); yel = M('#E8B43A', .5, .3); tile = M('#D9CDB4', .5)
    with at(g):
        boxab((-.7, -.55, 0), (.7, .55, .75), tile, .02)                                            # bệ ốp gạch men
        for x in np.linspace(-.6, .6, 5): boxab((x - .005, -.56, .02), (x + .005, -.55, .73), M('#B9AE98', .6), 0)
        boxab((-.75, -.6, .75), (.75, .6, .8), M('#B9B3A6', .8), .01)
        boxab((-.5, -.35, .8), (.5, .35, 1.55), red, .02)                                            # thân miếu
        boxab((-.32, -.37, .9), (.32, -.34, 1.42), M('#3A1E14', .6), .005)                           # khám
        for i, x in enumerate((-.14, .14)):
            cyl(.07, .22, (x, -.2, 1.0), M('#E9C9A0', .5), n=10); ball(.07, (x, -.2, 1.17), M('#E9C9A0', .5), sub=1)
            cyl(.08, .05, (x, -.2, 1.25), yel, n=10)
        for x in (-.42, .42): cyl(.04, .75, (x, -.38, 1.18), yel, n=10)
        # mái cong ngói đỏ, đầu đao vểnh
        V = [(-.75, -.55, 1.55), (.75, -.55, 1.55), (.75, .55, 1.55), (-.75, .55, 1.55), (-.45, 0, 1.95), (.45, 0, 1.95)]
        mesh_obj('mai', V, [(0, 1, 5, 4), (2, 3, 4, 5), (1, 2, 5), (3, 0, 4)], M(C['tile'], .7))
        cyl(.04, .95, (0, 0, 1.97), M('#3F8A5C', .5), rot=(0, math.pi / 2, 0), n=8)
        for sx in (-1, 1):
            for sy in (-1, 1): curve([(sx * .75, sy * .55, 1.55), (sx * .88, sy * .65, 1.66)], .025, M('#3F8A5C', .5))
            ball(.06, (sx * .5, 0, 2.0), yel, sub=1)
        text('PHƯỚC ĐỨC', .07, (0, -.36, 1.48), yel, extrude=.003)
        # lư hương, nhang, mâm trái cây, đèn dầu, ly nước
        cyl(.1, .1, (0, -.42, .85), yel, n=14, r2=.12)
        for i in range(5): cyl(.004, .3, (-.04 + i * .02, -.42, 1.05), M('#C8412F', .6), rot=(.1 * (i - 2), 0, 0), n=4, bv=0)
        for i in range(5): ball(.06, (.3 + (i % 3) * .07, -.42 + (i // 3) * .06, .9), M(['#E8913A', '#3F8A5C', '#F2B33D', '#C8412F', '#E8913A'][i], .6), sub=1)
        cyl(.1, .02, (.37, -.4, .82), M('#E9E2D2', .5), n=14)
        for x in (-.3, -.42): cyl(.025, .08, (x, -.42, .86), M('#DDEBEE', .1, alpha=.5), n=8)
        ball(.035, (-.36, -.3, 1.0), M('#FFB040', .3, emit=2.0), sub=1)
        # cây bồ đề nhỏ sau miếu + chậu bông vạn thọ hai bên
        curve([(.2, .8, 0), (.25, .8, 1.5), (.0, .85, 2.4)], .08, M('#8C7A66', .9))
        rnd = random.Random(5)
        for i in range(12): ball(rnd.uniform(.22, .36), (rnd.uniform(-.55, .65), .8 + rnd.uniform(-.3, .3), 2.2 + rnd.uniform(0, .6)), M(C['leaf'] if i % 2 else C['leaf2'], .85, sheen=.3), sub=2)
        for sx in (-.9, .9):
            cyl(.14, .22, (sx, -.35, .11), M('#B4553A', .8), n=12, r2=.17)
            for i in range(6): ball(.07, (sx + rnd.uniform(-.1, .1), -.35 + rnd.uniform(-.1, .1), .3 + rnd.uniform(0, .1)), M('#F29A1E' if i % 2 else C['leaf'], .7), sub=1)
    return g, dict(the_tich=[1.5, 1.2, 2.0], ghi='đặt ở đầu hẻm, mặt quay ra đường; bệ 0,8 m Bơ nhảy lên được (chỗ ngồi nghỉ)')

def truong_mau_giao(name='mau_giao', loc=(0, 0, 0)):
    """Trường mầm non 2 tầng, tường vàng, khung cửa ba màu, sân trước có cầu tuột, cổng sắt vòm có bảng tên."""
    w, d = 12.0, 8.0; g = group(name, loc); wall = M('#F2D27A', .85); trim = M('#F6F0E2', .8)
    H1, H2 = 3.4, 6.6; frames = ['#3A6EA5', '#C8412F', '#3F8A5C']
    with at(g):
        boxab((0, 0, 0), (w, d, H2), wall, .03)
        for z in (H1, H2): boxab((-.05, -1.4 if z == H1 else -.1, z - .12), (w + .05, d, z + .1), trim, .03)
        # hành lang tầng 2 có lan can hoa văn cầu vồng
        for x in np.arange(.15, w - .1, .25):
            boxab((x - .03, -1.35, H1 + .1), (x + .03, -1.3, H1 + 1.0), M(frames[int(x / .25) % 3], .5), 0)
        boxab((0, -1.4, H1 + 1.0), (w, -1.25, H1 + 1.08), trim, .01)
        for x in (0, 4, 8, w - .25): boxab((x, -1.4, 0), (x + .25, -1.15, H1), trim, .02)
        for i in range(4):                                                                          # cửa lớp
            for f, z in enumerate((0, H1)):
                x = 1.5 + i * 3.0
                fc = M(frames[(i + f) % 3], .5)
                boxab((x - .5, -.06, z + .2), (x + .5, .0, z + 2.3), fc, .01)
                boxab((x - .42, -.08, z + .3), (x + .42, -.05, z + 2.2), glass(i + f * 4) if NIGHT[0] else M('#9FC6D8', .1), 0)
                boxab((x + .8, -.06, z + 1.0), (x + 1.6, .0, z + 2.0), fc, .01)
                boxab((x + .86, -.08, z + 1.06), (x + 1.54, -.05, z + 1.94), M('#9FC6D8', .1), 0)
        # tranh vẽ tường: mặt trời, mây, mèo
        cyl(.45, .03, (10.6, -.02, 5.2), M('#F29A1E', .6), rot=(math.pi / 2, 0, 0), n=20, bv=0)
        for k in range(8):
            a = k * math.pi / 4; box((.08, .03, .3), (10.6 + math.cos(a) * .65, -.02, 5.2 + math.sin(a) * .65), M('#F29A1E', .6), 0, rot=(0, -a + math.pi / 2, 0))
        for k, (cx, cz) in enumerate(((.8, 5.6), (1.3, 5.75), (1.8, 5.6))): cyl(.3, .03, (cx, -.02, cz), M('#FFFFFF', .7), rot=(math.pi / 2, 0, 0), n=16, bv=0)
        text('TRƯỜNG MẦM NON SƠN CA', .32, (w / 2, -.12, H2 - .5), M('#C8412F', .5), extrude=.02)
        # mái tôn đỏ sau tường lửng
        boxab((0, -.1, H2), (w, .2, H2 + .6), wall, .02)
        corrugated(w + .1, d + .2, M(C['ton_red'], .45, .5), (w / 2, d / 2, H2 + .55), rot=(-.06, 0, 0), period=.2, amp=.025)
        # sân trước: cầu tuột, xích đu, nền cao su
        yr = -5.0
        boxab((.2, yr + .1, 0), (w - .2, -1.5, .03), M('#7DB46C', .9), 0)
        gs = group('cau_tuot', (2.6, -3.2, 0))
        with at(gs):
            boxab((-.5, -.5, 0), (.5, .5, 1.2), M('#3A6EA5', .5), .03)
            boxab((-.55, -.55, 1.2), (.55, .55, 1.28), M('#F2B33D', .5), .02)
            o = box((.6, 2.2, .06), (1.35, 0, .62), M('#C8412F', .4, coat=.4), .02); o.rotation_euler = (0, 0, 0)
            o.rotation_euler = (math.atan2(1.2, 2.2), 0, math.pi / 2)
            for k in range(4): boxab((-.5, -.62, .25 + k * .28), (.5, -.55, .3 + k * .28), M('#F2B33D', .5), 0)
        gx = group('xich_du', (7.0, -3.3, 0))
        with at(gx):
            for sx in (-1.2, 1.2):
                for sy in (-.5, .5): curve([(sx, sy, 0), (sx, 0, 2.2)], .04, M('#3F8A5C', .5))
            cyl(.04, 2.5, (0, 0, 2.2), M('#3F8A5C', .5), rot=(0, math.pi / 2, 0), n=8)
            for sx in (-.5, .5):
                for dx in (-.2, .2): cyl(.006, 1.6, (sx + dx, 0, 1.4), M(C['steel'], .3, .9), n=4, bv=0)
                box((.5, .2, .05), (sx, 0, .6), M('#C8412F', .5), .02)
        # tường rào + cổng sắt vòm
        for (x0, x1) in ((0, 4.8), (7.2, w)):
            boxab((x0, yr - .2, 0), (x1, yr, .6), wall, .02)
            for x in np.arange(x0 + .1, x1, .15): boxab((x - .012, yr - .11, .6), (x + .012, yr - .09, 1.6), M(frames[int(x / .15) % 3], .5), 0)
            boxab((x0, yr - .12, 1.58), (x1, yr - .08, 1.62), M(C['iron'], .5, .6), 0)
        for x in (4.8, 7.2): boxab((x - .2, yr - .25, 0), (x + .2, yr + .05, 2.6), wall, .02)
        arc = [(4.8 + 2.4 * t, yr - .1, 2.6 + .6 * math.sin(math.pi * t)) for t in np.linspace(0, 1, 12)]
        curve(arc, .06, M(C['iron'], .5, .6))
        boxab((5.0, yr - .14, 2.75), (7.0, yr - .06, 3.15), M('#2457A0', .5), .02)
        text('MẦM NON SƠN CA', .2, (6.0, yr - .15, 2.95), M('#FFFFFF', .5), extrude=.005)
        for k, (x0, x1) in enumerate(((5.0, 6.0), (6.0, 7.0))):                                     # cổng lùa
            for x in np.arange(x0 + .05, x1, .1): boxab((x - .01, yr - .11 - k * .08, .05), (x + .01, yr - .09 - k * .08, 1.8), M(C['iron'], .5, .6), 0)
            for zz in (.1, 1.0, 1.78): boxab((x0, yr - .12 - k * .08, zz - .02), (x1, yr - .08 - k * .08, zz + .02), M(C['iron'], .5, .6), 0)
    return g, dict(the_tich=[w, d, H2 + .6], san_truoc=5.0, ghi='mái tôn 6,6–7,2 m; cổng lùa mở/đóng theo giờ (sáng, chiều tan trường)')

def chung_cu_2(name='chung_cu_2', loc=(0, 0, 0)):
    """Chung cư cũ thứ hai ở vành bắc (ô x 20→44), nhìn sang ban công Bé Na. 6 tầng × 3 m, 5 căn mỗi tầng + khối cầu thang 3 m = 24 m, hành lang quay về phía Hoa Sữa."""
    units, floors, uw, d, Fh = 5, 6, 4.2, 10.0, 3.0
    w = units * uw; H = floors * Fh; g = group(name, loc)
    wall = M('#AEBDBE', .9); wall2 = M('#97A8AA', .9); trim = M('#E3E0D6', .85)
    with at(g):
        boxab((0, 1.8, 0), (w, d, H), wall, .03)
        for f in range(floors):
            z = f * Fh
            boxab((-.1, -.1, z - .1 if f else -.05), (w + .1, 1.9, z + .12), trim, .03)
            for u in range(units):
                x0 = u * uw; s = u * 7 + f
                boxab((x0 + .25, 1.75, z + .12), (x0 + 1.15, 1.82, z + 2.2), M(['#3E6E6E', '#7A4E36', '#4A5E7A', '#6E5A3A'][(u + f) % 4], .6), .01)
                boxab((x0 + 1.7, 1.75, z + .9), (x0 + 3.3, 1.8, z + 2.1), glass(s, 1.2) if NIGHT[0] else M('#3A4644', .4), 0)
                if (u + f) % 3 != 1:   # chuồng cọp nhô ra hành lang
                    m = M(C['iron'], .5, .6)
                    for xx in np.linspace(x0 + 1.6, x0 + 3.4, 8): boxab((xx - .01, 1.3, z + .7), (xx + .01, 1.33, z + 2.3), m, 0)
                    boxab((x0 + 1.6, 1.3, z + 2.3), (x0 + 3.4, 1.8, z + 2.34), m, 0)
                if (u + 2 * f) % 4 == 1: laundry(x0 + .3, x0 + uw - .3, .25, z + 2.6, seed=s)
                if (u * 3 + f) % 5 == 2: ac_unit((x0 + 3.0, 1.6, z + 2.6), 0)
                if (u + f) % 4 == 0 and f: plant_pot((x0 + .6, .35, z + .12), kind='bush', s=.55)
            if f: railing(0, w, -.05, z + .12, h=1.05, deco=False)
            for u in range(units + 1): boxab((u * uw - .15, -.15, z), (u * uw + .15, .15, z + Fh), trim, .02)
        boxab((-.2, -.25, H - .05), (w + .2, d + .2, H + .25), trim, .03)
        railing(0, w, -.1, H + .25, h=.9, deco=False)
        for i in range(3): water_tank((3 + i * 7, d - 1.5, H + .25), horizontal=bool(i % 2))
        antenna((12, 4, H + .25))
        boxab((w, 0, 0), (w + 3.0, d * .7, H + 1.2), wall2, .03)                                  # khối cầu thang
        for f in range(floors):
            for i in range(5):
                for j in range(5): torus(.12, .025, (w + .35 + i * .55, -.03, f * Fh + .7 + j * .38), trim, rot=(math.pi / 2, 0, 0), n=10, m=4)
        text('CHUNG CƯ NGỌC LAN', .5, (w / 2, -.3, H - .5), M('#3E5A6A', .6), extrude=.02)
        text('LÔ C', .6, (w + 1.5, -.08, H + .4), M('#3E5A6A', .6), extrude=.02)
        boxab((w + .6, -.1, 0), (w + 2.4, .05, 2.4), M('#1E2424', .6), .01)
    return g, dict(the_tich=[w + 3.0, d, H + 1.2], ghi='mặt hành lang quay về Hoa Sữa (Godot +z); ban công tầng 4 (z 9–12 m) ngang tầm Bé Na',
                   o_dat='x 20→44, mặt tiền z=-31,5, sâu tới z=-45 (theo P1)')

MOC = dict(nha_dang_xay=nha_dang_xay, biet_thu=biet_thu_phap, mieu=mieu_tho_dia, mau_giao=truong_mau_giao, chung_cu_2=chung_cu_2)
MOC_TEN = dict(nha_dang_xay='Nhà đang xây có giàn giáo', biet_thu='Biệt thự Pháp cũ ở góc', mieu='Miếu thổ địa đầu hẻm',
               mau_giao='Trường mẫu giáo cổng sắt', chung_cu_2='Chung cư cũ thứ hai (vành phố)')

# ---------------------------------------------------------------- 12 căn ráp thử
NHA12 = [
    dict(w=4.0, tret='tap_hoa', lau=['ban_cong', 'cua_chop'], mai='san_thuong', son='vang_nghe', bang=0, seed=1),
    dict(w=3.2, tret='nha_o', lau=['chuong_cop', 'chuong_cop', 'tuong_kin'], mai='ton', son='xanh_ngoc', seed=2),
    dict(w=4.8, tret='quan_pho', lau=['lo_gia'], mai='ngoi', son='kem', bang=0, seed=3),
    dict(w=4.0, tret='sua_dt', lau=['kinh_lua', 'kinh_lua', 'kinh_lua', 'kinh_lua'], mai='tum', son='xam_trang', bang=0, seed=4),
    dict(w=3.2, tret='hot_toc', lau=['cua_chop'], mai='luoi', son='da_troi', bang=0, seed=5),
    dict(w=6.0, tret='gui_xe', lau=['ban_cong', 'ban_cong'], mai='san_thuong', son='cam_dat', bang=1, seed=6),
    dict(w=4.0, tret='tiem_thuoc', lau=['tuong_kin', 'lo_gia', 'cua_chop'], mai='tum', son='bac_ha', bang=0, seed=7),
    dict(w=3.2, tret='tiem_may', lau=['ban_cong'], mai='ngoi', son='hong_phan', bang=0, seed=8),
    dict(w=4.8, tret='nha_o', lau=['lo_gia', 'chuong_cop', 'cua_chop'], mai='luoi', son='la_non', seed=9),
    dict(w=4.0, tret='tap_hoa', lau=['cua_chop', 'ban_cong', 'kinh_lua'], mai='ton', son='vang_chanh', bang=2, seed=10),
    dict(w=6.0, tret='quan_pho', lau=['kinh_lua', 'kinh_lua'], mai='san_thuong', son='xanh_ngoc', bang=2, seed=11),
    dict(w=3.2, tret='nha_o', lau=[], mai='ton', son='cam_dat', seed=12),
]
