"""21 bảng hiệu riêng cho 7 kiểu tiệm: mỗi bảng một dáng, chất liệu, kiểu chữ và hình vẽ của nghề.
Gọi bang_hieu(ten, phu, w) trong nhóm tầng trệt: bảng nằm trên dầm cửa, z 2,54–3,30, mặt trước y ≈ -0,1.
Trong game: khung + hình vẽ là lưới (vài trăm tam giác), chữ là ảnh dán chung một tấm atlas."""
import os, math, random
import numpy as np
import bpy
import kit
from kit import M, C, box, boxab, cyl, ball, torus, curve, mesh_obj, corrugated, group, at

HERE = os.path.dirname(os.path.abspath(__file__))
# Phông chữ không đưa vào repo (nặng 3 MB): mặc định lấy ở thư mục gói P2 trong project files
FONT_DIR = os.environ.get('NHA_RAP_FONTS', '/mnt/project-files/thiet-ke-lai-khu-pho/p2-bo-rap-nha/scripts/fonts')
FONTS = dict(baloo=os.path.join(FONT_DIR, 'Baloo2.ttf'), lobster=os.path.join(FONT_DIR, 'Lobster.ttf'),
             pattaya=os.path.join(FONT_DIR, 'Pattaya.ttf'), inter='/usr/share/fonts/opentype/inter/Inter-Black.otf',
             inter_b='/usr/share/fonts/opentype/inter/Inter-ExtraBold.otf', paytone=os.path.join(FONT_DIR, 'PaytoneOne-Regular.ttf'),
             bungee=os.path.join(FONT_DIR, 'Bungee-Regular.ttf'), pacifico=os.path.join(FONT_DIR, 'Pacifico-Regular.ttf'),
             tay=os.path.join(FONT_DIR, 'PatrickHand-Regular.ttf'), stencil=os.path.join(FONT_DIR, 'SairaStencilOne-Regular.ttf'),
             playfair=os.path.join(FONT_DIR, 'PlayfairDisplaySC-Black.ttf'), chonburi=os.path.join(FONT_DIR, 'Chonburi-Regular.ttf'))
LITE = bool(os.environ.get('LITE'))
GAME_CHU = None   # xuat_game.py gán []: chỉ ghi khung chữ cho atlas thay vì dựng chữ
from mathutils import Vector
NIGHT = [False]
ZC, HMAX, Y = 2.92, .76, -.04          # tâm, cao tối đa, mặt sau bảng

def glow(hexc, day=.35, night=2.4): return M(hexc, .4, emit=night if NIGHT[0] else day)

def chu(body, size, loc, mat, font='baloo', maxw=None, extrude=.012, align='CENTER'):
    """Chữ nổi, tự thu nhỏ cho vừa maxw."""
    if LITE and GAME_CHU is None: return None
    cu = bpy.data.curves.new('chu', 'FONT'); cu.body = body; cu.size = size; cu.extrude = extrude
    cu.font = bpy.data.fonts.load(FONTS[font], check_existing=True); cu.align_x = align; cu.align_y = 'CENTER'
    o = bpy.data.objects.new('chu', cu); o.location = loc; o.rotation_euler = (math.pi / 2, 0, 0); cu.materials.append(mat)
    kit._link(o)
    if maxw:
        bpy.context.view_layer.update(); wx = o.dimensions.x
        if wx > maxw: cu.size = size * maxw / wx
    if GAME_CHU is not None:   # bản game: chỉ ghi khung chữ (toạ độ Blender) để vẽ lên atlas, không xuất lưới chữ
        bpy.context.view_layer.update()
        pts = [o.matrix_world @ Vector(c) for c in o.bound_box]
        GAME_CHU.append(dict(chu=body, font=font, mau=mat.name.split('_', 1)[1], sang=bool(mat.node_tree.nodes['Principled BSDF'].inputs['Emission Strength'].default_value > .5),
                             x=[min(p.x for p in pts), max(p.x for p in pts)], z=[min(p.z for p in pts), max(p.z for p in pts)], y=min(p.y for p in pts)))
        bpy.data.objects.remove(o, do_unlink=True)
        return None
    return o

def plate(cx, cz, w, h, mat, d=.06, y=Y, bv=.015):
    return boxab((cx - w / 2, y - d, cz - h / 2), (cx + w / 2, y, cz + h / 2), mat, bv)

def rim(cx, cz, w, h, mat, t=.04, d=.07, y=Y):
    for (a, b) in (((cx - w / 2, cz + h / 2 - t), (cx + w / 2, cz + h / 2)), ((cx - w / 2, cz - h / 2), (cx + w / 2, cz - h / 2 + t)),
                   ((cx - w / 2, cz - h / 2), (cx - w / 2 + t, cz + h / 2)), ((cx + w / 2 - t, cz - h / 2), (cx + w / 2, cz + h / 2))):
        boxab((a[0], y - d, a[1]), (b[0], y + .002, b[1]), mat, .005)

def disc(r, loc, mat, d=.03, n=24, sx=1.0, sz=1.0):
    o = cyl(r, d, loc, mat, rot=(math.pi / 2, 0, 0), n=n, bv=.004); o.scale = (sx, sz, 1); return o

def arch_plate(cx, cz, w, h, mat, rise=.22, d=.06, y=Y, n=14):
    """Bảng đầu vòm: đáy phẳng, đỉnh cong."""
    top = [(cx - w / 2 + w * i / n, cz + h / 2 - rise + rise * math.sin(math.pi * i / n)) for i in range(n + 1)]
    pts = [(cx - w / 2, cz - h / 2), (cx + w / 2, cz - h / 2)] + top[::-1]
    k = len(pts); V = [(x, y - d, z) for x, z in pts] + [(x, y, z) for x, z in pts]
    F = [tuple(range(k))[::-1], tuple(range(k, 2 * k))] + [(i, (i + 1) % k, k + (i + 1) % k, k + i) for i in range(k)]
    return mesh_obj('vom', V, F, mat)

def bolts(cx, cz, w, h, y=Y - .065):
    for sx in (-1, 1):
        for sz in (-1, 1): ball(.018, (cx + sx * (w / 2 - .06), y, cz + sz * (h / 2 - .06)), M(C['steel'], .3, .9), sub=1)

# ---------------------------------------------------------------- hình vẽ nghề (nổi 3D, quay mặt về -y)
F0 = Y - .07   # mặt trước chung của hình vẽ

def i_to_pho(x, z, s=1.0, y=F0):
    disc(.16 * s, (x, y, z - .02 * s), M('#F1ECE2', .4), d=.04, sx=1.0, sz=.45)      # miệng tô (nhìn chéo)
    mesh_obj('to', [(x - .16 * s, y, z), (x + .16 * s, y, z), (x + .08 * s, y, z - .14 * s), (x - .08 * s, y, z - .14 * s)], [(0, 1, 2, 3)], M('#F1ECE2', .4))
    box((.3 * s, .02, .025 * s), (x, y - .01, z - .06 * s), M('#2E7C80', .5), 0)          # viền xanh
    for k, dx in enumerate((-.05, .05)): box((.012 * s, .02, .32 * s), (x + dx * s + .1 * s, y - .02, z + .1 * s), M(C['wood2'], .6), 0, rot=(0, -.5, 0))
    for k in range(3):                                                                    # khói
        curve([(x - .07 * s + k * .07 * s, y - .02, z + .05 * s + j * .05 * s + .02 * math.sin(j * 1.7 + k)) for j in range(6)], .008 * s, M('#FFFFFF', .6))

def i_don_ganh(x, z, s=1.0, y=F0):
    cyl(.012 * s, .5 * s, (x, y, z + .1 * s), M(C['wood'], .6), rot=(0, math.pi / 2 - .12, 0), n=8, bv=0)
    for sx in (-1, 1):
        cx = x + sx * .2 * s; cz = z + .1 * s + sx * .025 * s
        for dx in (-.05, .05): curve([(cx, y, cz), (cx + dx * s, y, cz - .14 * s)], .004, M('#3A2A1E', .7))
        disc(.07 * s, (cx, y, cz - .17 * s), M(C['wood2'] if sx < 0 else C['steel'], .5), d=.03, sz=.5)
        box((.14 * s, .02, .06 * s), (cx, y, cz - .2 * s), M('#8A5A30' if sx < 0 else C['steel'], .6), 0)

def i_dien_thoai(x, z, s=1.0, y=F0, col='#1E2424'):
    box((.15 * s, .03, .28 * s), (x, y, z), M(col, .3), .02 * s)
    box((.12 * s, .012, .22 * s), (x, y - .016, z + .01 * s), glow('#7FD3F0', .6, 2.0), 0)
    disc(.012 * s, (x, y - .016, z - .118 * s), M('#888888', .4), d=.006, n=10)

def i_laptop(x, z, s=1.0, y=F0):
    box((.32 * s, .02, .2 * s), (x, y, z + .06 * s), M('#C9CED0', .3, .6), .01)
    box((.28 * s, .012, .16 * s), (x, y - .012, z + .06 * s), glow('#7FD3F0', .5, 1.8), 0)
    mesh_obj('day', [(x - .2 * s, y, z - .05 * s), (x + .2 * s, y, z - .05 * s), (x + .17 * s, y - .02, z - .08 * s), (x - .17 * s, y - .02, z - .08 * s)], [(0, 1, 2, 3)], M('#C9CED0', .3, .6))

def i_the_cao(x, z, s=1.0, y=F0):
    for k, c in enumerate(('#C8412F', '#F2B33D', '#3A6EA5')):
        box((.2 * s, .012, .12 * s), (x + (k - 1) * .06 * s, y - k * .006, z + (k - 1) * .03 * s), M(c, .5), .005, rot=(0, (k - 1) * .25, 0))

def i_keo(x, z, s=1.0, y=F0, col=None):
    m = M(col or '#6B6F73', .3, .8)
    for sx in (-1, 1):
        torus(.045 * s, .012 * s, (x + sx * .05 * s, y, z - .1 * s), m, rot=(math.pi / 2, 0, 0), n=14, m=5)
        box((.02 * s, .015, .2 * s), (x + sx * .02 * s, y, z + .02 * s), m, 0, rot=(0, sx * .35, 0))
    ball(.014 * s, (x, y - .012, z - .03 * s), m, sub=1)

def i_ong_chi(x, z, s=1.0, y=F0, col='#D2368A'):
    cyl(.05 * s, .02, (x, y, z), M(col, .7, sheen=.5), rot=(math.pi / 2, 0, 0), n=16, bv=0); o = box((.12 * s, .025, .2 * s), (x, y + .002, z), M(col, .7, sheen=.5), .005)
    for dz in (-.11, .11): box((.15 * s, .03, .03 * s), (x, y - .004, z + dz * s), M(C['wood2'], .6), .005)
    curve([(x + .06 * s, y - .01, z + .05 * s), (x + .2 * s, y - .01, z - .02 * s), (x + .25 * s, y - .01, z + .1 * s)], .004, M(col, .7))

def i_kim(x, z, s=1.0, y=F0):
    box((.008 * s, .012, .3 * s), (x, y, z), M(C['steel'], .3, .9), 0, rot=(0, .6, 0))
    torus(.012 * s, .003 * s, (x + .088 * s, y, z + .125 * s), M(C['steel'], .3, .9), rot=(math.pi / 2, 0, 0), n=8, m=3)
    curve([(x + .088 * s, y - .005, z + .12 * s), (x + .2 * s, y - .005, z + .2 * s), (x + .25 * s, y - .005, z), (x + .15 * s, y - .005, z - .1 * s)], .004, M('#C8412F', .7))

def i_ao_dai(x, z, s=1.0, y=F0, col='#F7EEDC'):
    m = M(col, .6, sheen=.5)
    mesh_obj('ao', [(x - .05 * s, y, z + .18 * s), (x + .05 * s, y, z + .18 * s), (x + .07 * s, y, z + .02 * s), (x + .1 * s, y, z - .2 * s),
                    (x - .1 * s, y, z - .2 * s), (x - .07 * s, y, z + .02 * s)], [(0, 1, 2, 3, 4, 5)], m)
    for sx in (-1, 1): box((.035 * s, .015, .17 * s), (x + sx * .1 * s, y, z + .1 * s), m, 0, rot=(0, -sx * .45, 0))
    box((.06 * s, .02, .03 * s), (x, y - .005, z + .19 * s), M('#C9A23D', .4, .5), 0)
    curve([(x - .07 * s, y - .01, z - .02 * s), (x, y - .01, z + .02 * s), (x + .07 * s, y - .01, z - .02 * s)], .005, M('#C9A23D', .4, .5))

def i_chu_thap(x, z, s=1.0, y=F0, col='#2EA35A'):
    for (a, b) in (((-.05, -.15), (.05, .15)), ((-.15, -.05), (.15, .05))):
        boxab((x + a[0] * s, y - .03, z + a[1] * s), (x + b[0] * s, y + .01, z + b[1] * s), glow(col, .5, 2.6), .006)

def i_con_nhong(x, z, s=1.0, y=F0):
    for k, (c, dx) in enumerate((('#C8412F', -1), ('#F1ECE2', 1))):
        cyl(.045 * s, .09 * s, (x + dx * .045 * s, y, z), M(c, .35, coat=.4), rot=(0, math.pi / 2, 0), n=14, bv=0)
        ball(.045 * s, (x + dx * .09 * s, y, z), M(c, .35, coat=.4), sub=2)

def i_tim(x, z, s=1.0, y=F0):
    for sx in (-1, 1): ball(.06 * s, (x + sx * .045 * s, y, z + .03 * s), M('#C8412F', .5), (1, .4, 1), sub=2)
    mesh_obj('tim', [(x - .1 * s, y, z + .02 * s), (x + .1 * s, y, z + .02 * s), (x, y, z - .12 * s)], [(0, 1, 2)], M('#C8412F', .5))
    pts = [(-.3, 0), (-.18, 0), (-.13, .08), (-.08, -.1), (-.04, .04), (0, 0), (.3, 0)]
    curve([(x + px * s + .32 * s, y - .02, z + pz * s) for px, pz in pts], .006, glow('#2EA35A', .4, 2.0))

def i_xe_may(x, z, s=1.0, y=F0, col='#F2B33D'):
    m = M(col, .5)
    for dx in (-.16, .16): torus(.07 * s, .015 * s, (x + dx * s, y, z - .08 * s), m, rot=(math.pi / 2, 0, 0), n=16, m=4)
    mesh_obj('than', [(x - .17 * s, y, z - .02 * s), (x + .05 * s, y, z - .02 * s), (x + .12 * s, y, z + .1 * s), (x + .03 * s, y, z + .06 * s), (x - .15 * s, y, z + .04 * s)], [(0, 1, 2, 3, 4)], m)
    box((.16 * s, .02, .025 * s), (x - .07 * s, y, z + .06 * s), m, 0)
    box((.012 * s, .02, .1 * s), (x + .12 * s, y, z + .12 * s), m, 0, rot=(0, -.4, 0))

def i_mui_ten(x, z, s=1.0, y=F0, col='#C8412F'):
    mesh_obj('ten', [(x - .2 * s, y, z - .04 * s), (x + .05 * s, y, z - .04 * s), (x + .05 * s, y, z - .1 * s), (x + .2 * s, y, z), (x + .05 * s, y, z + .1 * s),
                     (x + .05 * s, y, z + .04 * s), (x - .2 * s, y, z + .04 * s)], [(0, 1, 2, 3, 4, 5, 6)], M(col, .5))

def i_luoc(x, z, s=1.0, y=F0, col='#2B2B2B'):
    box((.26 * s, .02, .05 * s), (x, y, z + .06 * s), M(col, .4), .008)
    for i in range(12): box((.008 * s, .018, .1 * s), (x - .12 * s + i * .022 * s, y, z - .01 * s), M(col, .4), 0)

def i_dao_cao(x, z, s=1.0, y=F0):
    box((.08 * s, .02, .3 * s), (x, y, z - .05 * s), M('#3A2A1E', .5), .01, rot=(0, .5, 0))
    box((.06 * s, .012, .24 * s), (x + .11 * s, y - .004, z + .1 * s), M(C['steel'], .2, .95), .004, rot=(0, .5, 0))

def i_may_say(x, z, s=1.0, y=F0, col='#F1ECE2'):
    cyl(.07 * s, .26 * s, (x + .02 * s, y, z + .06 * s), M(col, .4), rot=(0, math.pi / 2, 0), n=16, bv=.01)
    cyl(.05 * s, .04 * s, (x + .17 * s, y, z + .06 * s), M('#555555', .4), rot=(0, math.pi / 2, 0), n=14, bv=0)
    box((.06 * s, .03, .2 * s), (x - .04 * s, y, z - .1 * s), M(col, .4), .015, rot=(0, -.25, 0))
    for k in range(3): curve([(x + .22 * s + j * .04 * s, y - .01, z + .1 * s - k * .04 * s + .012 * math.sin(j * 2)) for j in range(4)], .004, M('#FFFFFF', .6))

def i_chai(x, z, s=1.0, y=F0, col='#3F8A5C'):
    cyl(.045 * s, .18 * s, (x, y, z - .04 * s), M(col, .2, alpha=.85), rot=(0, 0, 0), n=12, bv=.01)
    cyl(.02 * s, .08 * s, (x, y, z + .09 * s), M(col, .2, alpha=.85), n=10, bv=0); cyl(.022 * s, .02 * s, (x, y, z + .14 * s), M('#C8412F', .4), n=10, bv=0)
    box((.07 * s, .02, .06 * s), (x, y - .04 * s, z - .04 * s), M('#F1ECE2', .6), 0)

def i_keo_goi(x, z, s=1.0, y=F0, col='#F2B33D'):
    box((.14 * s, .03, .08 * s), (x, y, z), M(col, .5), .015)
    for sx in (-1, 1): mesh_obj('xoan', [(x + sx * .07 * s, y - .01, z), (x + sx * .13 * s, y - .01, z + .05 * s), (x + sx * .13 * s, y - .01, z - .05 * s)], [(0, 1, 2)], M(col, .5))

def i_bao_gao(x, z, s=1.0, y=F0):
    mesh_obj('bao', [(x - .1 * s, y, z - .13 * s), (x + .1 * s, y, z - .13 * s), (x + .12 * s, y, z + .08 * s), (x + .06 * s, y, z + .14 * s), (x - .06 * s, y, z + .14 * s), (x - .12 * s, y, z + .08 * s)],
             [(0, 1, 2, 3, 4, 5)], M('#E9DFC4', .9))
    for k in range(3): box((.16 * s, .012, .012 * s), (x, y - .006, z - .06 * s + k * .05 * s), M('#C8412F', .6), 0)
    for k in range(5): ball(.016 * s, (x - .04 * s + k * .02 * s, y - .01, z + .16 * s + (k % 2) * .01 * s), M('#FFFFFF', .6), sub=1)

def i_cuc_da(x, z, s=1.0, y=F0):
    for k, (dx, dz) in enumerate(((-.07, -.05), (.07, -.05), (0, .07))):
        box((.12 * s, .04, .12 * s), (x + dx * s, y, z + dz * s), M('#CFEFF5', .1, alpha=.8, coat=.8), .02 * s, rot=(0, .2 * (k - 1), 0))

def i_chu_P(x, z, s=1.0, y=F0):
    boxab((x - .14 * s, y - .02, z - .14 * s), (x + .14 * s, y + .01, z + .14 * s), M('#2457A0', .5), .03 * s)
    chu('P', .26 * s, (x, y - .03, z - .005 * s), M('#FFFFFF', .4), 'inter', extrude=.008)

# ---------------------------------------------------------------- 21 bảng
def _sub(t, size, cx, cz, mat, font='inter_b', maxw=None): return chu(t, size, (cx, F0 - .005, cz), mat, font, maxw, extrude=.005)

def tap_hoa_co_ut(w, name, sub):          # tôn đỏ sơn tay, chữ trắng tròn, chai nước + gói kẹo
    cx = w / 2; bw = w - .3
    corrugated(HMAX, bw, M('#B8322A', .55, .3), (cx, Y - .04, ZC), rot=(0, math.pi / 2, math.pi / 2), period=.1, amp=.012)
    boxab((cx - bw / 2 - .03, Y - .06, ZC + HMAX / 2), (cx + bw / 2 + .03, Y, ZC + HMAX / 2 + .04), M(C['iron'], .5, .6), 0)
    chu(name, .3, (cx, F0 - .01, ZC + .07), M('#FFF3D6', .5), 'paytone', bw - .8)
    _sub(sub, .13, cx, ZC - .24, M('#F2B33D', .5), 'tay')
    i_chai(cx - bw / 2 + .2, ZC, 1.4); i_keo_goi(cx + bw / 2 - .22, ZC + .1, 1.2); i_keo_goi(cx + bw / 2 - .25, ZC - .12, 1.0, col='#3A6EA5')

def tap_hoa_thu_ha(w, name, sub):         # tấm xanh lá viền vàng góc bo, bao gạo, chữ kem
    cx = w / 2; bw = w - .35
    plate(cx, ZC, bw, .7, M('#2F6B45', .5), bv=.05); rim(cx, ZC, bw - .04, .66, M('#E8B43A', .4, .4), t=.03)
    chu(name, .28, (cx + .15, F0, ZC + .08), M('#F6EED8', .5), 'chonburi', bw - .75)
    _sub(sub, .12, cx + .15, ZC - .22, M('#E8B43A', .5), 'inter_b')
    i_bao_gao(cx - bw / 2 + .25, ZC, 1.5)

def tap_hoa_bay_hien(w, name, sub):       # chữ sơn thẳng lên tường vàng, cục đá, khung vẽ tay
    cx = w / 2; bw = w - .3
    boxab((cx - bw / 2, Y - .005, ZC - .36), (cx + bw / 2, Y + .01, ZC + .36), M('#F2D27A', .9), 0)
    chu(name, .36, (cx + .12, Y - .02, ZC + .07), M('#1F3F86', .6), 'tay', bw - .7, extrude=.004)
    _sub(sub, .13, cx + .12, ZC - .23, M('#C8412F', .6), 'tay')
    i_cuc_da(cx - bw / 2 + .22, ZC, 1.2)
    for dz in (-.33, .33): box((bw, .012, .02), (cx, Y - .02, ZC + dz), M('#C8412F', .6), 0)

def pho_ba_tam(w, name, sub):             # bảng vàng, tô phở bốc khói, chữ đỏ dày
    cx = w / 2; bw = w - .3
    plate(cx, ZC, bw, .72, M('#F2B33D', .45), bv=.03); rim(cx, ZC, bw, .72, M('#8A2A1E', .5), t=.035)
    chu(name, .32, (cx + .2, F0, ZC + .06), M('#8A2A1E', .5), 'paytone', bw - .9)
    _sub(sub, .12, cx + .2, ZC - .24, M('#8A2A1E', .5), 'inter_b')
    i_to_pho(cx - bw / 2 + .32, ZC, 1.3)

def pho_ganh(w, name, sub):               # ván gỗ ngang ghép, chữ khắc, đòn gánh
    cx = w / 2; bw = w - .35
    for k in range(3): boxab((cx - bw / 2, Y - .05, ZC - .36 + k * .24), (cx + bw / 2, Y, ZC - .36 + k * .24 + .225), M(['#9C6A40', '#8A5A30', '#A8784A'][k], .85), .01)
    for sx in (-1, 1): boxab((cx + sx * (bw / 2 - .05) - .025, Y - .07, ZC - .38), (cx + sx * (bw / 2 - .05) + .025, Y - .04, ZC + .38), M('#5E3E22', .8), .005)
    chu(name, .27, (cx + .18, F0 + .01, ZC + .06), M('#F6EED8', .6), 'pacifico', bw - .85, extrude=.006)
    _sub(sub, .13, cx + .18, ZC - .25, M('#F2D27A', .6), 'tay')
    i_don_ganh(cx - bw / 2 + .32, ZC, 1.2)

def pho_nam_cuong(w, name, sub):          # hộp đèn đỏ, viền vàng lượn, chữ vàng, hai đèn lồng nhỏ
    cx = w / 2; bw = w - .3
    plate(cx, ZC, bw, .74, M(C['steel'], .3, .7), d=.16, bv=.02)
    plate(cx, ZC, bw - .08, .66, glow('#C8312A', .3, 1.4), d=.17, bv=0)
    for k in range(int(bw / .25)): ball(.03, (cx - bw / 2 + .12 + k * .25, F0 - .1, ZC + .3), M('#F2C14E', .3, .5), sub=1)
    chu(name, .27, (cx, F0 - .11, ZC + .05), glow('#FFD76A', .4, 2.4), 'inter', bw - .7)
    _sub(sub, .1, cx, F0 - .1 + .0 if False else ZC - .24, M('#FFE9B0', .5), 'inter_b')
    for sx in (-1, 1):
        ball(.09, (cx + sx * (bw / 2 - .15), F0 - .15, ZC - .02), glow('#E2362A', .4, 1.8), (1, 1, 1.25), sub=2)
        cyl(.05, .03, (cx + sx * (bw / 2 - .15), F0 - .15, ZC + .1), M('#E8B43A', .4, .4), n=10, bv=0)

def dt_tuan(w, name, sub):                # hộp đèn xanh viền LED chấm, điện thoại phát sáng
    cx = w / 2; bw = w - .3
    plate(cx, ZC, bw, .72, M('#C9CED0', .3, .6), d=.14, bv=.015)
    plate(cx, ZC, bw - .06, .66, glow('#1F5FB0', .25, 1.3), d=.145, bv=0)
    n = int(bw / (.09 if not LITE else .3))   # bản game bớt chấm LED (bàn giao P2: dt_tuan giảm lưới mạnh)
    for k in range(n):
        for zz in (ZC + .3, ZC - .3): ball(.012, (cx - bw / 2 + .06 + k * (bw - .12) / (n - 1), F0 - .08, zz), glow(['#FF5050', '#50FF80', '#50A0FF'][k % 3], 1.0, 3.0), sub=1)
    chu(name, .26, (cx + .18, F0 - .09, ZC + .06), M('#FFFFFF', .4, emit=1.5 if NIGHT[0] else .2), 'inter', bw - .8)
    _sub(sub, .12, cx + .18, ZC - .2, M('#FFE36A', .4), 'inter_b')
    i_dien_thoai(cx - bw / 2 + .26, ZC, 1.6, y=F0 - .085)

def dt_kim_ngan(w, name, sub):            # nền vàng chữ đỏ, dải thẻ cào xếp quạt bên phải
    cx = w / 2; bw = w - .3
    plate(cx, ZC, bw, .7, M('#F5D547', .45), bv=.02); rim(cx, ZC, bw, .7, M('#C8412F', .5), t=.05)
    chu(name, .26, (cx - .2, F0, ZC + .07), M('#C8412F', .45), 'paytone', bw - .9)
    _sub(sub, .12, cx - .2, ZC - .22, M('#1F3A5F', .5), 'inter_b')
    i_the_cao(cx + bw / 2 - .3, ZC + .02, 1.4); i_dien_thoai(cx + bw / 2 - .12, ZC - .05, 1.0, col='#C8412F')

def dt_minh(w, name, sub):                # chữ rời inox trên mảng ốp xám, laptop
    cx = w / 2; bw = w - .3
    plate(cx, ZC, bw, .72, M('#3B4448', .6), d=.03, bv=.005)
    for k in range(int(bw / .3)): boxab((cx - bw / 2 + k * .3, Y - .032, ZC - .36), (cx - bw / 2 + k * .3 + .005, Y - .028, ZC + .36), M('#2E3538', .6), 0)
    chu(name, .3, (cx + .2, Y - .05, ZC + .06), M('#D9DDDD', .15, .95), 'inter', bw - .85, extrude=.03)
    _sub(sub, .12, cx + .2, ZC - .22, M('#8FD3E8', .4), 'inter_b')
    i_laptop(cx - bw / 2 + .3, ZC, 1.3, y=Y - .05)

def may_hong_nhung(w, name, sub):         # bảng bầu dục hồng, chữ Lobster, kéo + cuộn chỉ
    cx = w / 2; bw = w - .35
    disc(.5, (cx, Y - .03, ZC), M('#F3C9D8', .5), d=.05, n=40, sx=bw / 1.0, sz=.72)
    o = torus(.5, .018, (cx, Y - .06, ZC), M('#A32B66', .4), rot=(math.pi / 2, 0, 0), n=40, m=6); o.scale = (bw / 1.0, .72, 1)
    chu(name, .27, (cx, F0 + .01, ZC + .06), M('#A32B66', .45), 'lobster', bw - 1.0)
    _sub(sub, .12, cx, ZC - .2, M('#5E2A40', .5), 'tay')
    i_keo(cx - bw / 2 + .32, ZC, 1.3); i_ong_chi(cx + bw / 2 - .34, ZC, 1.0)

def may_thanh_thao(w, name, sub):         # bảng vòm trắng ngà viền vàng, hình áo dài
    cx = w / 2; bw = w - .35
    arch_plate(cx, ZC - .01, bw, .74, M('#F6F0E2', .5), rise=.2)
    box((bw, .02, .03), (cx, Y - .065, ZC - .36), M('#C9A23D', .4, .5), 0)
    chu(name, .25, (cx + .15, F0, ZC + .0), M('#7A2E4E', .5), 'playfair', bw - .85)
    _sub(sub, .12, cx + .15, ZC - .25, M('#A07A20', .45), 'tay')
    i_ao_dai(cx - bw / 2 + .28, ZC - .02, 1.3, col='#E26A8A')

def may_be_tu(w, name, sub):              # bảng gỗ nhỏ treo xích, kim chỉ, chữ viết tay
    cx = w / 2; bw = min(w - .6, 2.4)
    for sx in (-1, 1): curve([(cx + sx * (bw / 2 - .1), Y - .03, ZC + .4), (cx + sx * (bw / 2 - .1), Y - .03, ZC + .3)], .006, M(C['steel'], .3, .9))
    plate(cx, ZC - .03, bw, .58, M('#B9844F', .8), d=.05, bv=.04); rim(cx, ZC - .03, bw - .06, .52, M('#7E5232', .8), t=.025)
    chu(name, .22, (cx + .15, F0 + .015, ZC + .02), M('#2F2A26', .7), 'pattaya', bw - .65, extrude=.004)
    _sub(sub, .11, cx + .15, ZC - .2, M('#F6EED8', .6), 'tay')
    i_kim(cx - bw / 2 + .22, ZC - .03, 1.0, y=F0 + .015)

def thuoc_tam_an(w, name, sub):           # hộp đèn trắng chữ xanh + chữ thập xanh phát sáng
    cx = w / 2; bw = w - .3
    plate(cx, ZC, bw, .72, glow('#F4F7F4', .2, 1.0), d=.13, bv=.015)
    box((bw, .02, .05), (cx, Y - .135, ZC - .31), M('#2E8A4E', .5), 0)
    chu(name, .27, (cx + .22, F0 - .07, ZC + .06), M('#2E8A4E', .45), 'inter', bw - .85)
    _sub(sub, .12, cx + .22, ZC - .19, M('#5B6764', .5), 'inter_b')
    i_chu_thap(cx - bw / 2 + .3, ZC, 1.6, y=F0 - .07)

def thuoc_hanh_phuc(w, name, sub):        # xanh lá đậm chữ trắng, viên con nhộng, góc bo tròn
    cx = w / 2; bw = w - .3
    plate(cx, ZC, bw, .7, M('#2E7A52', .45), bv=.08); rim(cx, ZC, bw - .08, .62, M('#FFFFFF', .5), t=.015)
    chu(name, .25, (cx + .2, F0, ZC + .06), M('#FFFFFF', .45), 'paytone', bw - .85)
    _sub(sub, .12, cx + .2, ZC - .22, M('#BDE5C8', .5), 'inter_b')
    i_con_nhong(cx - bw / 2 + .3, ZC, 1.6)

def thuoc_minh_chau(w, name, sub):        # kính mờ khung nhôm, chữ rời xanh dương, tim + nhịp tim
    cx = w / 2; bw = w - .3
    plate(cx, ZC, bw, .72, M('#E3EEF2', .1, alpha=.85, coat=.8), d=.03, bv=.005); rim(cx, ZC, bw, .72, M('#B9C1C3', .3, .7), t=.025)
    chu(name, .25, (cx - .25, Y - .05, ZC + .06), M('#1F5FB0', .4), 'inter', bw - .95, extrude=.025)
    _sub(sub, .12, cx - .25, ZC - .22, M('#C8412F', .5), 'inter_b')
    i_tim(cx + bw / 2 - .55, ZC, 1.1, y=Y - .05)

def xe_giu_xe(w, name, sub):              # sơn tường: dải xanh, chữ vàng to, xe máy vẽ khuôn
    cx = w / 2; bw = w - .3
    boxab((cx - bw / 2, Y - .005, ZC - .36), (cx + bw / 2, Y + .01, ZC + .36), M('#2457A0', .7), 0)
    chu(name, .38, (cx + .2, Y - .02, ZC + .04), M('#F2B33D', .6), 'stencil', bw - .9, extrude=.003)
    _sub(sub, .13, cx + .2, ZC - .26, M('#F1ECE2', .6), 'stencil')
    i_xe_may(cx - bw / 2 + .35, ZC, 1.5, y=Y - .02)

def xe_giu_xe_thang(w, name, sub):        # tôn trắng chữ đỏ, mũi tên chỉ vào, viền sắt
    cx = w / 2; bw = w - .3
    corrugated(.7, bw, M('#ECE8DE', .55, .2), (cx, Y - .03, ZC), rot=(0, math.pi / 2, math.pi / 2), period=.12, amp=.012)
    rim(cx, ZC, bw, .72, M(C['iron'], .5, .6), t=.03, d=.06)
    chu(name, .28, (cx - .2, F0, ZC + .06), M('#C8412F', .5), 'chonburi', bw - .9)
    _sub(sub, .12, cx - .2, ZC - .22, M('#2B2B2B', .5), 'inter_b')
    i_mui_ten(cx + bw / 2 - .33, ZC, 1.3)

def xe_gui_xe(w, name, sub):              # hộp đèn vàng, chữ P xanh, chữ đen
    cx = w / 2; bw = w - .3
    plate(cx, ZC, bw, .7, glow('#F5C53D', .2, 1.2), d=.12, bv=.015)
    chu(name, .32, (cx + .2, F0 - .06, ZC + .06), M('#1F1F1F', .5), 'inter', bw - .85)
    _sub(sub, .12, cx + .2, ZC - .22, M('#1F1F1F', .5), 'inter')
    i_chu_P(cx - bw / 2 + .3, ZC, 1.5, y=F0 - .06)

def toc_anh_ba(w, name, sub):             # bảng gỗ sẫm, viền sọc đỏ xanh trắng, chữ Lobster kem, kéo + lược
    cx = w / 2; bw = w - .3
    plate(cx, ZC, bw, .72, M('#3B2A20', .7), bv=.02)
    n = int(bw / .12)
    for k in range(n):
        for zz in (ZC + .33, ZC - .33): box((.1, .015, .05), (cx - bw / 2 + .06 + k * .12, Y - .065, zz), M(['#C8412F', '#F1ECE2', '#2457A0'][k % 3], .5), 0, rot=(0, .5, 0))
    chu(name, .28, (cx, F0, ZC + .04), M('#F2E3B8', .5), 'lobster', bw - 1.0)
    _sub(sub, .12, cx, ZC - .2, M('#C9A23D', .5), 'tay')
    i_keo(cx - bw / 2 + .28, ZC, 1.2, col='#C9CED0'); i_luoc(cx + bw / 2 - .3, ZC, 1.0, col='#E9E2D2')

def toc_my_linh(w, name, sub):            # hồng tím bóng, chữ Pattaya, máy sấy tóc, hạt lấp lánh
    cx = w / 2; bw = w - .3
    plate(cx, ZC, bw, .72, M('#7A3B78', .3, coat=.6), bv=.05)
    rnd = random.Random(4)
    for k in range(10): ball(.015, (cx + rnd.uniform(-bw / 2 + .1, bw / 2 - .1), F0 + .01, ZC + rnd.choice((-1, 1)) * rnd.uniform(.27, .32)), glow('#FFD6F2', .8, 2.5), sub=1)
    chu(name, .27, (cx + .2, F0, ZC + .04), M('#FFD6F2', .4), 'pacifico', bw - .85)
    _sub(sub, .12, cx + .2, ZC - .22, M('#F5C53D', .4), 'tay')
    i_may_say(cx - bw / 2 + .26, ZC, 1.2)

def toc_binh_dan(w, name, sub):           # tôn xanh dương chữ trắng, dao cạo
    cx = w / 2; bw = w - .3
    corrugated(.7, bw, M('#3A6EA5', .55, .3), (cx, Y - .03, ZC), rot=(0, math.pi / 2, math.pi / 2), period=.12, amp=.012)
    chu(name, .28, (cx + .18, F0, ZC + .06), M('#FFFFFF', .5), 'chonburi', bw - .85)
    _sub(sub, .12, cx + .18, ZC - .22, M('#F2B33D', .5), 'inter_b')
    i_dao_cao(cx - bw / 2 + .28, ZC, 1.3)

KIEU = {'TẠP HÓA CÔ ÚT': (tap_hoa_co_ut, 'Tôn đỏ sơn tay, chữ tròn trắng, chai nước và gói kẹo'),
        'TẠP HÓA THU HÀ': (tap_hoa_thu_ha, 'Tấm xanh lá bo góc viền vàng, bao gạo'),
        'TẠP HÓA BẢY HIỀN': (tap_hoa_bay_hien, 'Chữ viết tay sơn thẳng lên tường vàng, cục nước đá'),
        'PHỞ BÀ TÁM': (pho_ba_tam, 'Bảng vàng viền đỏ, tô phở bốc khói, đũa'),
        'PHỞ GÁNH CHÚ SÁU': (pho_ganh, 'Ba ván gỗ ghép, chữ viết tay, đòn gánh hai thúng'),
        'HỦ TIẾU MÌ NĂM CƯỜNG': (pho_nam_cuong, 'Hộp đèn đỏ khung inox, chữ vàng, hạt đèn và hai lồng đèn'),
        'SỬA ĐIỆN THOẠI TUẤN': (dt_tuan, 'Hộp đèn xanh viền đèn LED chấm, điện thoại sáng màn'),
        'ĐIỆN THOẠI KIM NGÂN': (dt_kim_ngan, 'Nền vàng viền đỏ, thẻ cào xếp quạt'),
        'SỬA MÁY MINH': (dt_minh, 'Chữ rời inox trên ốp xám, laptop'),
        'TIỆM MAY HỒNG NHUNG': (may_hong_nhung, 'Bảng bầu dục hồng, chữ uốn lượn, kéo và cuộn chỉ'),
        'NHÀ MAY THANH THẢO': (may_thanh_thao, 'Bảng vòm trắng ngà chỉ vàng, áo dài'),
        'TIỆM MAY BÉ TƯ': (may_be_tu, 'Bảng gỗ nhỏ treo hai móc, kim chỉ đỏ'),
        'NHÀ THUỐC TÂM AN': (thuoc_tam_an, 'Hộp đèn trắng, chữ thập xanh phát sáng'),
        'QUẦY THUỐC HẠNH PHÚC': (thuoc_hanh_phuc, 'Xanh lá bo tròn chỉ trắng, viên con nhộng'),
        'NHÀ THUỐC MINH CHÂU': (thuoc_minh_chau, 'Kính mờ khung nhôm, chữ rời xanh, tim và nhịp tim'),
        'GIỮ XE': (xe_giu_xe, 'Sơn tường dải xanh, chữ vàng to, xe máy vẽ khuôn'),
        'GIỮ XE THÁNG': (xe_giu_xe_thang, 'Tôn trắng chữ đỏ, mũi tên chỉ vào'),
        'GỬI XE': (xe_gui_xe, 'Hộp đèn vàng, ô chữ P xanh'),
        'HỚT TÓC ANH BA': (toc_anh_ba, 'Gỗ sẫm viền sọc đỏ trắng xanh, chữ cổ điển, kéo và lược'),
        'SALON TÓC MỸ LINH': (toc_my_linh, 'Tím hồng bóng, hạt lấp lánh, máy sấy tóc'),
        'HỚT TÓC BÌNH DÂN': (toc_binh_dan, 'Tôn xanh dương chữ trắng, dao cạo')}

def bang_hieu(name, sub, w):
    g = group('bang_hieu', (0, 0, 0))
    with at(g): KIEU[name][0](w, name, sub)
    return g
