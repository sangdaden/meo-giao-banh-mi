"""Bảng hiệu vòng 3: to hơn, mỗi quán một dấu nhận ra từ xa (Sang 27/10: "bảng hiệu các quán đều nhỏ và chưa có ấn tượng riêng").
Toạ độ bảng (Blender): x dọc mặt tiền 0..w, mặt bảng quay về -y, z tính từ đáy bảng (game: đáy 3,02 m, ngay trên mái hiên).
Mỗi bảng có 4 lớp tách được: 'bang' (tấm, khung, trang trí), 'chu' (chữ), 'hinh' (món nổi 3D của nghề), 'doc' (bảng dọc chìa ra phố).
Quy ước chung vòng 3:
  - tấm chính cao 1,2 m (cũ 0,72), chữ tên cao hoa ~0,33 m (cũ ~0,2), chữ phụ + số điện thoại;
  - món nổi 3D to, chìa ra trước mặt bảng 0,15–0,35 m hoặc nhô khỏi mép trên để phá dáng chữ nhật;
  - bảng dọc chìa ra phố 0,65 m, đặt trên tấm chính (z 1,25–2,75: trên đầu Bơ khi chạy mái hiên), hai mặt có chữ."""
import math, random
import bpy
import kit
from kit import M, C, box, boxab, cyl, ball, torus, curve, mesh_obj, corrugated, group, at
import bang_hieu as BH
import sys
from mathutils import Vector

H = 1.2          # cao tấm chính
FR = -.09        # mặt trước tấm chính
NIGHT = BH.NIGHT

def glow(hexc, day=.3, night=2.6, rough=.4): return M(hexc, rough, emit=night if NIGHT[0] else day)

def lit(hexc, night=1.3, rough=.4):
    """Chữ sơn ban ngày, ban đêm được đèn hắt sáng."""
    return M(hexc, rough, emit=night if NIGHT[0] else 0.0)

GAME_CHU = None   # run_v3.py game gán []: chữ không dựng lưới, chỉ ghi 4 góc mặt trước để vẽ lên atlas

def _hex(mat):
    c = mat.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value
    f = lambda v: round(255 * (12.92 * v if v <= .0031308 else 1.055 * v ** (1 / 2.4) - .055))
    return '#%02X%02X%02X' % (f(c[0]), f(c[1]), f(c[2]))

def _record(o, body, font, mat):
    bpy.context.view_layer.update()
    bb = [Vector(c) for c in o.bound_box]
    x0, x1 = min(c.x for c in bb), max(c.x for c in bb); y0, y1 = min(c.y for c in bb), max(c.y for c in bb); z1 = max(c.z for c in bb)
    pts = [o.matrix_world @ Vector(c) for c in ((x0, y0, z1), (x1, y0, z1), (x1, y1, z1), (x0, y1, z1))]
    # Godot: x, y = z Blender, z = -y Blender; nhô ra 3 mm trước mặt chữ
    GAME_CHU.append(dict(chu=body, font=font, mau=_hex(mat), p=[[round(q.x, 3), round(q.z, 3), round(-q.y, 3)] for q in pts]))

def txt(body, size, loc, mat, font='inter', maxw=None, rot=(math.pi / 2, 0, 0), extrude=.016, align='CENTER', shadow=None, sh_off=(.022, .006, -.022)):
    """Chữ nổi (tự thu cho vừa maxw). shadow = màu bóng đổ phía sau-dưới-phải cho dễ đọc từ xa."""
    cu = bpy.data.curves.new('chu', 'FONT'); cu.body = body; cu.size = size; cu.extrude = extrude
    cu.font = bpy.data.fonts.load(BH.FONTS[font], check_existing=True); cu.align_x = align; cu.align_y = 'CENTER'
    o = bpy.data.objects.new('chu', cu); o.location = loc; o.rotation_euler = rot; cu.materials.append(mat); kit._link(o)
    if maxw:
        bpy.context.view_layer.update(); wx = o.dimensions.x
        if wx > maxw: cu.size = size * maxw / wx
    if shadow:
        txt(body, cu.size, (loc[0] + sh_off[0], loc[1] + sh_off[1], loc[2] + sh_off[2]), M(shadow, .7), font, None, rot, extrude, align)
    if GAME_CHU is not None:
        _record(o, body, font, mat); bpy.data.objects.remove(o, do_unlink=True); return None
    return o

def rect(x0, x1, z0, z1, mat, d=.09, y=0.0, bv=.02): return boxab((x0, y - d, z0), (x1, y, z1), mat, bv)

def frame(x0, x1, z0, z1, mat, t=.05, d=.11, y=0.0):
    for a, b in (((x0, z1 - t), (x1, z1)), ((x0, z0), (x1, z0 + t)), ((x0, z0), (x0 + t, z1)), ((x1 - t, z0), (x1, z1))):
        boxab((a[0], y - d, a[1]), (b[0], y + .002, b[1]), mat, .006)

def disc(r, loc, mat, d=.04, n=28, sx=1.0, sz=1.0):
    """Đĩa tròn quay mặt ra phố. Bản game vẫn giữ ~20 cạnh cho huy hiệu tròn khỏi thành đa giác thô."""
    c = getattr(sys.modules.get('bo_rap'), '_cyl', None)
    if c is not None: o = c(r, d, loc, mat, rot=(math.pi / 2, 0, 0), n=min(n, 20) if r > .2 else min(n, 12), bv=0)
    else: o = cyl(r, d, loc, mat, rot=(math.pi / 2, 0, 0), n=n, bv=.004)
    o.scale = (sx, sz, 1); return o

def bulbs(x0, x1, z, y, n, col='#FFD27A', r=.035):
    for k in range(n): ball(r, (x0 + (x1 - x0) * k / max(n - 1, 1), y, z), glow(col, .6, 4.0), sub=1)

class Layers:
    """Bốn nhóm con của một bảng; explode > 0 kéo các lớp ra cho ảnh tách bộ phận."""
    def __init__(self, root, explode=0.0):
        self.g = {}
        off = dict(bang=(0, 0, 0), chu=(0, -explode * .5, explode * 2.0), hinh=(0, -explode * 1.0, explode * 4.0), doc=(explode * 1.6, 0, explode * 2.4))
        with at(root):
            for k in ('bang', 'chu', 'hinh', 'doc'): self.g[k] = group(k, off[k])
    def __getitem__(self, k): return at(self.g[k])

# ---------------------------------------------------------------- bảng dọc chìa ra phố (một kiểu cho mỗi nghề)
def _blade_frame(x, z0, z1, out, mat_face, mat_rim, thick=.12):
    """Hộp bảng dọc vuông góc mặt tiền ở x, chìa ra (−y) từ .12 tới out, cùng hai tay sắt."""
    boxab((x - thick / 2, -out, z0), (x + thick / 2, -.12, z1), mat_face, .02)
    for zz in (z0 + .08, z1 - .08): boxab((x - .015, -.14, zz - .015), (x + .015, 0, zz + .015), M(C['iron'], .5, .6), 0)
    for a, b in (((-out - .02, z1 - .03), (-.1, z1 + .03)), ((-out - .02, z0 - .03), (-.1, z0 + .03))):
        boxab((x - thick / 2 - .01, a[0], a[1]), (x + thick / 2 + .01, b[0], b[1]), mat_rim, .005)

def _blade_words(x, words, zc, step, size, mat, font, thick=.12, out=.65, shadow=None):
    """Chữ xếp dọc từng dòng, cả hai mặt bảng dọc."""
    yc = -(out + .12) / 2
    for side in (1, -1):
        for i, wd in enumerate(words):
            txt(wd, size, (x + side * (thick / 2 + .002), yc, zc - i * step), mat, font, out - .12, rot=(math.pi / 2, 0, side * math.pi / 2), extrude=.008, shadow=None)

BZ0, BZ1, BOUT = 1.28, 2.78, .7     # bảng dọc: đáy, đỉnh, chìa ra

def blade(kind, x, bg, fg, rim='#E8E2D2', words=None, font='inter'):
    if kind == 'pho':          # đèn tô phở treo: tô úp tròn + chữ PHỞ
        _blade_frame(x, BZ0 + .45, BZ1, BOUT, M(bg, .5), M(rim, .4, .4))
        _blade_words(x, words or ['PHỞ'], BZ1 - .55, .4, .42, M(fg, .4), font)
        yc = -(BOUT + .12) / 2
        disc(.32, (x, yc, BZ0 + .25), glow('#F5EBD8', .3, 2.2), d=.16, n=24, sz=.55)
        cyl(.33, .05, (x, yc, BZ0 + .38), M('#2E7C80', .5), n=24, bv=0)
    elif kind == 'thuoc':      # chữ thập xanh hộp đèn hai mặt — dấu hiệu nhà thuốc ai cũng nhận ra
        yc = -(BOUT + .12) / 2; m = glow(bg, .6, 3.2)
        for (sx, sz) in ((.6, .2), (.2, .6)):
            boxab((x - .07, yc - sx / 2, BZ1 - .45 - sz / 2), (x + .07, yc + sx / 2, BZ1 - .45 + sz / 2), m, .01)
        boxab((x - .01, -.12, BZ1 - .47), (x + .01, yc - .3, BZ1 - .43), M(C['iron'], .5, .6), 0)
        _blade_frame(x, BZ0, BZ1 - .9, BOUT, M('#F4F7F4', .4), M(bg, .5))
        _blade_words(x, words or ['THUỐC'], BZ1 - 1.2, .3, .2, M(bg, .4), 'inter')
    elif kind == 'toc':        # cột xoay sọc đỏ trắng xanh (game cho xoay chậm)
        yc = -.42
        for k in range(12):
            cyl(.13, .12, (x, yc, BZ0 + .3 + k * .12), M(['#C8412F', '#F4F1E8', '#2457A0', '#F4F1E8'][k % 4], .35, coat=.6), n=16, bv=0)
        for zz in (BZ0 + .2, BZ0 + .3 + 12 * .12 + .02): cyl(.16, .1, (x, yc, zz), M(C['steel'], .25, .9), n=16, bv=.01)
        ball(.16, (x, yc, BZ0 + .3 + 12 * .12 + .14), glow('#FFF4D6', .4, 2.4), (1, 1, .7), sub=2)
        for zz in (BZ0 + .3, BZ0 + 1.6): boxab((x - .02, -.3, zz - .02), (x + .02, 0, zz + .02), M(C['iron'], .5, .6), 0)
    elif kind == 'xe':         # ô chữ P vuông xanh hai mặt
        yc = -(BOUT + .12) / 2
        boxab((x - .07, yc - .29, BZ1 - .62), (x + .07, yc + .29, BZ1 - .04), glow('#2457A0', .25, 1.6), .03)
        for side in (1, -1): txt('P', .5, (x + side * .072, yc, BZ1 - .33), M('#FFFFFF', .4), 'inter', rot=(math.pi / 2, 0, side * math.pi / 2), extrude=.01)
        _blade_frame(x, BZ0 + .2, BZ1 - .7, BOUT, M(bg, .5), M(rim, .5))
        _blade_words(x, words or ['GIỮ XE'], BZ1 - .98, .3, .2, M(fg, .4), 'inter')
        boxab((x - .01, -.12, BZ1 - .35), (x + .01, yc - .29, BZ1 - .31), M(C['iron'], .5, .6), 0)
    elif kind == 'may':        # kéo khổng lồ cắt bằng tôn sơn
        yc = -.42; m = M(fg, .3, .8)
        for sx in (-1, 1):
            o = torus(.17, .045, (x, yc + sx * .17, BZ0 + .35), m, rot=(0, math.pi / 2, 0), n=18, m=6)
            boxab((x - .03, yc + sx * .17 - .05, BZ0 + .5), (x + .03, yc + sx * .17 + .05, BZ0 + 1.45), m, .01)
        box((.06, .5, .07), (x, yc, BZ0 + .95), m, .01)
        _blade_frame(x, BZ0 + 1.55, BZ1, BOUT, M(bg, .5), M(rim, .5))
        _blade_words(x, words or ['MAY'], BZ1 - .6, .3, .34, M(fg, .4), font)
    elif kind == 'dt':         # điện thoại khổng lồ màn sáng
        yc = -(BOUT + .12) / 2
        boxab((x - .08, yc - .3, BZ0 + .1), (x + .08, yc + .3, BZ1 - .05), M(bg, .3, coat=.5), .08)
        for side in (1, -1):
            boxab((x + side * .081 - .005, yc - .24, BZ0 + .35), (x + side * .081 + .005, yc + .24, BZ1 - .3), glow('#8FE0FF', .5, 2.6), 0)
            txt(words[0] if words else 'ĐT', .26, (x + side * .088, yc, BZ0 + 1.0), M('#123', .4) if fg is None else M(fg, .4), 'inter', .44, rot=(math.pi / 2, 0, side * math.pi / 2), extrude=.006)
        boxab((x - .01, -.12, BZ1 - .25), (x + .01, yc - .3, BZ1 - .21), M(C['iron'], .5, .6), 0)
    else:                      # 'tap_hoa' và mặc định: hộp đèn chữ dọc
        _blade_frame(x, BZ0, BZ1, BOUT, glow(bg, .2, 1.3, .5), M(rim, .5))
        _blade_words(x, words or ['TẠP', 'HÓA'], BZ1 - .4, .5, .36, M(fg, .4), font)

# ---------------------------------------------------------------- 21 bảng quán thường: giữ màu, chất liệu, kiểu chữ đã duyệt (vòng 2), làm to
# shape: rect | tin | paint | light | oval | arch | planks | hang | glass
GEN = {
 'TẠP HÓA CÔ ÚT':      dict(sub='bánh kẹo · nước ngọt', shape='tin', bg='#B8322A', fg='#FFF3D6', sb='#F2B33D', font='paytone', sh='#5A1410', icon=('i_chai', 1, {}), icon2=('i_keo_goi', 1, {}), blade=('tap_hoa', '#B8322A', '#FFF3D6')),
 'TẠP HÓA THU HÀ':     dict(sub='gạo · mắm · dầu ăn', shape='rect', bg='#2F6B45', rim='#E8B43A', fg='#F6EED8', sb='#E8B43A', font='chonburi', sh='#163322', icon=('i_bao_gao', 1, {}), blade=('tap_hoa', '#2F6B45', '#F6EED8')),
 'TẠP HÓA BẢY HIỀN':   dict(sub='nước đá · ve chai', shape='paint', bg='#F2D27A', fg='#1F3F86', sb='#C8412F', font='tay', icon=('i_cuc_da', 1, {}), stripes='#C8412F', blade=('tap_hoa', '#1F3F86', '#F2D27A')),
 'PHỞ BÀ TÁM':         dict(sub='phở bò · hủ tiếu', shape='rect', bg='#F2B33D', rim='#8A2A1E', fg='#8A2A1E', sb='#8A2A1E', font='paytone', sh='#FFF0C8', icon=('i_to_pho', 1, {}), blade=('pho', '#F2B33D', '#8A2A1E')),
 'PHỞ GÁNH CHÚ SÁU':   dict(sub='phở gà · bún bò', shape='planks', bg='#9C6A40', fg='#F6EED8', sb='#F2D27A', font='pacifico', sh='#3A2410', icon=('i_don_ganh', 1, {}), blade=('pho', '#8A5A30', '#F6EED8')),
 'HỦ TIẾU MÌ NĂM CƯỜNG': dict(sub='hủ tiếu nam vang', shape='light', bg='#C8312A', rim=C['steel'], fg='#FFD76A', sb='#FFE9B0', font='inter', sh='#5A1410', deco='lanterns', blade=('pho', '#C8312A', '#FFD76A')),
 'SỬA ĐIỆN THOẠI TUẤN': dict(sub='ép kính · thay pin', shape='light', bg='#1F5FB0', rim='#C9CED0', fg='#FFFFFF', sb='#FFE36A', font='inter', sh='#0C2850', icon=('i_dien_thoai', 1, {}), deco='led', blade=('dt', '#1F5FB0', '#FFFFFF')),
 'ĐIỆN THOẠI KIM NGÂN': dict(sub='sim · thẻ cào · phụ kiện', shape='rect', bg='#F5D547', rim='#C8412F', fg='#C8412F', sb='#1F3A5F', font='paytone', sh='#FFF6C8', icon=('i_the_cao', 1, {}), right=True, blade=('dt', '#C8412F', '#FFFFFF')),
 'SỬA MÁY MINH':       dict(sub='điện thoại · máy tính', shape='rect', bg='#3B4448', fg='#E4E8E8', sb='#8FD3E8', font='inter', sh='#15191B', icon=('i_laptop', 1, {}), metal_txt=True, blade=('dt', '#3B4448', '#8FD3E8')),
 'TIỆM MAY HỒNG NHUNG': dict(sub='may đo · sửa đồ', shape='oval', bg='#F3C9D8', rim='#A32B66', fg='#A32B66', sb='#5E2A40', font='lobster', sh='#FFFFFF', icon=('i_keo', 1, {}), icon2=('i_ong_chi', 1, {}), blade=('may', '#F3C9D8', '#A32B66')),
 'NHÀ MAY THANH THẢO': dict(sub='áo dài · đồng phục', shape='arch', bg='#F6F0E2', rim='#C9A23D', fg='#7A2E4E', sb='#A07A20', font='playfair', icon=('i_ao_dai', 1, {'col': '#E26A8A'}), blade=('may', '#F6F0E2', '#7A2E4E')),
 'TIỆM MAY BÉ TƯ':     dict(sub='lên lai · thay dây kéo', shape='hang', bg='#B9844F', rim='#7E5232', fg='#2F2A26', sb='#F6EED8', font='pattaya', icon=('i_kim', 1, {}), blade=('may', '#B9844F', '#2F2A26')),
 'NHÀ THUỐC TÂM AN':   dict(sub='thuốc tây · y cụ', shape='light', bg='#F4F7F4', rim='#2E8A4E', fg='#2E8A4E', sb='#5B6764', font='inter', icon=('i_chu_thap', 1, {}), band='#2E8A4E', blade=('thuoc', '#2EA35A', '#FFFFFF')),
 'QUẦY THUỐC HẠNH PHÚC': dict(sub='thuốc tây · sữa', shape='rect', bg='#2E7A52', rim='#FFFFFF', fg='#FFFFFF', sb='#BDE5C8', font='paytone', sh='#143A26', icon=('i_con_nhong', 1, {}), round=True, blade=('thuoc', '#2EA35A', '#FFFFFF')),
 'NHÀ THUỐC MINH CHÂU': dict(sub='đo huyết áp miễn phí', shape='glass', bg='#E3EEF2', rim='#B9C1C3', fg='#1F5FB0', sb='#C8412F', font='inter', icon=('i_tim', 1, {}), right=True, blade=('thuoc', '#2EA35A', '#FFFFFF')),
 'GIỮ XE':             dict(sub='ngày · đêm', shape='paint', bg='#2457A0', fg='#F2B33D', sb='#F1ECE2', font='stencil', icon=('i_xe_may', 1, {}), blade=('xe', '#2457A0', '#F2B33D')),
 'GIỮ XE THÁNG':       dict(sub='an toàn · có mái che', shape='tin', bg='#ECE8DE', rim=C['iron'], fg='#C8412F', sb='#2B2B2B', font='chonburi', icon=('i_mui_ten', 1, {}), right=True, blade=('xe', '#ECE8DE', '#C8412F')),
 'GỬI XE':             dict(sub='24/24', shape='light', bg='#F5C53D', rim='#C9CED0', fg='#1F1F1F', sb='#1F1F1F', font='inter', icon=('i_chu_P', 1, {}), blade=('xe', '#F5C53D', '#1F1F1F')),
 'HỚT TÓC ANH BA':     dict(sub='cắt · gội · cạo mặt', shape='rect', bg='#3B2A20', fg='#F2E3B8', sb='#C9A23D', font='lobster', sh='#120A06', icon=('i_keo', 1, {'col': '#C9CED0'}), icon2=('i_luoc', 1, {'col': '#E9E2D2'}), deco='barber', blade=('toc', '#3B2A20', '#F2E3B8')),
 'SALON TÓC MỸ LINH':  dict(sub='uốn · nhuộm · duỗi', shape='rect', bg='#7A3B78', fg='#FFD6F2', sb='#F5C53D', font='pacifico', sh='#341533', icon=('i_may_say', 1, {}), deco='sparkle', round=True, blade=('toc', '#7A3B78', '#FFD6F2')),
 'HỚT TÓC BÌNH DÂN':   dict(sub='cắt tóc nam', shape='tin', bg='#3A6EA5', fg='#FFFFFF', sb='#F2B33D', font='chonburi', sh='#16304D', icon=('i_dao_cao', 1, {}), blade=('toc', '#3A6EA5', '#FFFFFF')),
}
# Cỡ chữ riêng từng quán (Sang 27/10: "mỗi quán một fontsize luôn cũng được"): (cỡ tên, dòng nhỏ phía trên, tên to, cỡ chữ phụ).
# Tên ngắn được chữ thật to; vài quán tách "nghề" thành dòng nhỏ để tên chủ quán to hẳn.
CO = {
 'TẠP HÓA CÔ ÚT': (.78, 'TẠP HÓA', 'CÔ ÚT', .17), 'TẠP HÓA THU HÀ': (.46, None, 'TẠP HÓA THU HÀ', .16),
 'TẠP HÓA BẢY HIỀN': (.66, None, 'TẠP HÓA BẢY HIỀN', .2), 'PHỞ BÀ TÁM': (.72, None, 'PHỞ BÀ TÁM', .17),
 'PHỞ GÁNH CHÚ SÁU': (.62, 'phở gánh', 'Chú Sáu', .17), 'HỦ TIẾU MÌ NĂM CƯỜNG': (.6, 'HỦ TIẾU MÌ', 'NĂM CƯỜNG', .15),
 'SỬA ĐIỆN THOẠI TUẤN': (.42, None, 'SỬA ĐIỆN THOẠI TUẤN', .16), 'ĐIỆN THOẠI KIM NGÂN': (.6, 'ĐIỆN THOẠI', 'KIM NGÂN', .15),
 'SỬA MÁY MINH': (.6, None, 'SỬA MÁY MINH', .15), 'TIỆM MAY HỒNG NHUNG': (.66, 'tiệm may', 'Hồng Nhung', .15),
 'NHÀ MAY THANH THẢO': (.44, None, 'NHÀ MAY THANH THẢO', .14), 'TIỆM MAY BÉ TƯ': (.5, None, 'Tiệm may Bé Tư', .14),
 'NHÀ THUỐC TÂM AN': (.5, None, 'NHÀ THUỐC TÂM AN', .17), 'QUẦY THUỐC HẠNH PHÚC': (.58, 'QUẦY THUỐC', 'HẠNH PHÚC', .15),
 'NHÀ THUỐC MINH CHÂU': (.38, None, 'NHÀ THUỐC MINH CHÂU', .17), 'GIỮ XE': (.95, None, 'GIỮ XE', .2),
 'GIỮ XE THÁNG': (.55, None, 'GIỮ XE THÁNG', .16), 'GỬI XE': (.85, None, 'GỬI XE', .22),
 'HỚT TÓC ANH BA': (.74, 'hớt tóc', 'Anh Ba', .16), 'SALON TÓC MỸ LINH': (.78, 'salon tóc', 'Mỹ Linh', .16),
 'HỚT TÓC BÌNH DÂN': (.46, None, 'HỚT TÓC BÌNH DÂN', .17),
}
PHONE = {k: '%s 0%d%02d %03d %03d' % ('ĐT', 9 if i % 3 else 3, 8 + i % 2, 100 + i * 37 % 900, 211 + i * 53 % 700) for i, k in enumerate(GEN)}

def _plate(sp, x0, x1, z0, z1):
    sh = sp['shape']; bg = sp['bg']; rim = sp.get('rim', '#E8E2D2'); cx = (x0 + x1) / 2; bw = x1 - x0; hh = z1 - z0; cz = (z0 + z1) / 2
    if sh == 'tin':
        corrugated(hh, bw, M(bg, .55, .3), (cx, -.05, cz), rot=(0, math.pi / 2, math.pi / 2), period=.12, amp=.016)
        boxab((x0 - .03, -.1, z1), (x1 + .03, 0, z1 + .05), M(C['iron'], .5, .6), 0); boxab((x0 - .03, -.1, z0 - .05), (x1 + .03, 0, z0), M(C['iron'], .5, .6), 0)
    elif sh == 'paint':
        boxab((x0, -.02, z0), (x1, 0, z1), M(bg, .9), 0)
        if sp.get('stripes'):
            for dz in (.06, hh - .06): box((bw, .012, .04), (cx, -.025, z0 + dz), M(sp['stripes'], .6), 0)
    elif sh == 'light':
        rect(x0, x1, z0, z1, M(rim, .3, .7), d=.18, bv=.02); rect(x0 + .05, x1 - .05, z0 + .05, z1 - .05, glow(bg, .25, 1.4, .5), d=.185, bv=0)
        if sp.get('band'): box((bw - .1, .02, .07), (cx, -.19, z0 + .14), M(sp['band'], .5), 0)
    elif sh == 'oval':
        disc(.5, (cx, -.04, cz), M(bg, .5), d=.06, n=48, sx=bw, sz=hh * 1.02)
        o = torus(.5, .022, (cx, -.075, cz), M(rim, .4), rot=(math.pi / 2, 0, 0), n=48, m=6); o.scale = (bw, hh * 1.02, 1)
    elif sh == 'arch':
        BH.arch_plate(cx, cz, bw, hh, M(bg, .5), rise=.3, d=.08, y=0.0); box((bw, .02, .04), (cx, -.09, z0 + .03), M(rim, .4, .5), 0)
    elif sh == 'planks':
        for k in range(4): boxab((x0, -.06, z0 + k * hh / 4), (x1, 0, z0 + (k + 1) * hh / 4 - .015), M(['#9C6A40', '#8A5A30', '#A8784A', '#94643A'][k], .85), .012)
        for sx in (x0 + .07, x1 - .07): boxab((sx - .03, -.085, z0 - .03), (sx + .03, -.05, z1 + .03), M('#5E3E22', .8), .006)
    elif sh == 'hang':          # tấm gỗ treo xích dưới thanh sắt ngang
        boxab((x0 - .05, -.05, z1 + .12), (x1 + .05, 0, z1 + .16), M(C['iron'], .5, .6), 0)
        for sx in (x0 + .25, x1 - .25): curve([(sx, -.03, z1 + .12), (sx, -.03, z1 - .02)], .008, M(C['steel'], .3, .9))
        rect(x0, x1, z0, z1, M(bg, .8), d=.06, bv=.05); frame(x0 + .05, x1 - .05, z0 + .05, z1 - .05, M(rim, .8), t=.035, d=.075)
    elif sh == 'glass':
        rect(x0, x1, z0, z1, M(bg, .1, alpha=.85, coat=.8), d=.035, bv=.005); frame(x0, x1, z0, z1, M(rim, .3, .7), t=.035, d=.05)
    else:
        rect(x0, x1, z0, z1, M(bg, .45), bv=.12 if sp.get('round') else .025)
        if sp.get('rim'): frame(x0 + .04, x1 - .04, z0 + .04, z1 - .04, M(rim, .45, .3), t=.04, d=.105)

def _deco(sp, x0, x1, z0, z1):
    d = sp.get('deco'); y = FR - .1
    if d == 'led':
        n = int((x1 - x0) / .1)
        for zz in (z0 + .06, z1 - .06):
            for k in range(n): ball(.016, (x0 + .06 + k * (x1 - x0 - .12) / (n - 1), -.2, zz), glow(['#FF5050', '#50FF80', '#50A0FF'][k % 3], 1.0, 3.5), sub=1)
    elif d == 'lanterns':
        bulbs(x0 + .15, x1 - .15, z1 - .08, -.2, int((x1 - x0) / .22), '#F2C14E', .03)
        for sx in (x0 + .32, x1 - .32):
            ball(.17, (sx, -.32, (z0 + z1) / 2 - .05), glow('#E2362A', .5, 2.2), (1, 1, 1.25), sub=2)
            cyl(.08, .05, (sx, -.32, (z0 + z1) / 2 + .18), M('#E8B43A', .4, .4), n=10, bv=0); cyl(.08, .05, (sx, -.32, (z0 + z1) / 2 - .28), M('#E8B43A', .4, .4), n=10, bv=0)
    elif d == 'barber':
        n = int((x1 - x0) / .14)
        for k in range(n):
            for zz in (z0 + .06, z1 - .06): box((.11, .015, .06), (x0 + .07 + k * .14, -.1, zz), M(['#C8412F', '#F1ECE2', '#2457A0'][k % 3], .5), 0, rot=(0, .5, 0))
    elif d == 'sparkle':
        rnd = random.Random(4)
        for k in range(18): ball(.022, (rnd.uniform(x0 + .1, x1 - .1), -.1, rnd.choice((z0 + rnd.uniform(.05, .14), z1 - rnd.uniform(.05, .14)))), glow('#FFD6F2', .9, 3.0), sub=1)

def generic(name, w, L):
    sp = GEN[name]; x0, x1 = .1, w - .1
    z0, z1 = (.15, H - .05) if sp['shape'] == 'hang' else (0.0, H)
    if sp['shape'] == 'hang': x0, x1 = .35, w - .35
    right = sp.get('right'); cx = (x0 + x1) / 2
    with L['bang']: _plate(sp, x0, x1, z0, z1); _deco(sp, x0, x1, z0, z1)
    # Hình nghề to (x3 bản vòng 2) trên nền tròn tương phản, chìa ra trước mặt bảng
    icon_w = 1.2; ix = (x1 - .58) if right else (x0 + .58); iz = (z0 + z1) / 2
    yf = FR - (.1 if sp['shape'] == 'light' else 0)
    with L['hinh']:
        if sp.get('icon') and sp['shape'] not in ('oval', 'glass', 'paint', 'hang'):
            disc(.47, (ix, yf - .02, iz), M(sp.get('sh', '#FFFFFF') if sp['bg'] not in ('#F4F7F4', '#F5C53D', '#F2B33D') else '#FFFFFF', .5), d=.05, n=32)
            torus(.47, .025, (ix, yf - .05, iz), M(sp.get('rim', sp['fg']), .4, .3), rot=(math.pi / 2, 0, 0), n=32, m=5)
        if sp.get('icon'): fn, _, kw = sp['icon']; getattr(BH, fn)(ix, iz, 2.7 if fn not in ('i_xe_may', 'i_laptop', 'i_mui_ten') else 2.1, y=yf - .08, **kw)
        if sp.get('icon2'):
            fn2, _, kw2 = sp['icon2']; ox = (x0 + .55) if right else (x1 - .5); getattr(BH, fn2)(ox, iz, 2.0, y=yf - .02, **kw2)
    tx0 = x0 + (.15 if right else icon_w + .1); tx1 = x1 - (icon_w + .1 if right else (.9 if sp.get('icon2') else .15))
    if sp['shape'] in ('oval',): tx0, tx1 = x0 + 1.0, x1 - 1.0
    if not sp.get('icon'): tx0, tx1 = x0 + .65, x1 - .65
    tcx = (tx0 + tx1) / 2; tw = tx1 - tx0
    yt = FR - (.11 if sp['shape'] == 'light' else 0) - (.005 if sp['shape'] != 'paint' else -.065)
    mt = M(sp['fg'], .15, .9) if sp.get('metal_txt') else glow(sp['fg'], .15, 1.8, .45) if sp['shape'] == 'light' else lit(sp['fg'], 1.0)
    sz, top, main, subsz = CO.get(name, (.5, None, name, .17))
    hh = z1 - z0; ex = .03 if sp.get('metal_txt') else .016
    with L['chu']:
        if top:    # hai dòng: chữ nghề nhỏ phía trên, tên quán thật to phía dưới
            txt(top, sz * .36, (tcx, yt, z0 + hh * .84), M(sp['sb'], .5), sp['font'], tw * .7, extrude=.01)
            txt(main, sz, (tcx, yt, z0 + hh * .53), mt, sp['font'], tw - .06, extrude=ex, shadow=sp.get('sh'))
        else:
            txt(main, sz, (tcx, yt, z0 + hh * .64), mt, sp['font'], tw - .06, extrude=ex, shadow=sp.get('sh'))
        txt(sp['sub'], subsz, (tcx, yt, z0 + hh * (.26 if top else .3)), M(sp['sb'], .5), 'inter_b' if sp['font'] not in ('tay', 'stencil') else sp['font'], tw * .8, extrude=.008)
        txt(PHONE[name], .11, (tcx, yt, z0 + (z1 - z0) * .12), M(sp['sb'], .5), 'inter_b', tw * .6, extrude=.006)
    kind, bbg, bfg = sp['blade']
    words = {'tap_hoa': ['TẠP', 'HÓA'], 'pho': ['PHỞ'] if 'PHỞ' in name else ['HỦ', 'TIẾU'], 'dt': ['ĐT'], 'may': ['MAY'], 'thuoc': ['THUỐC'], 'xe': ['GIỮ XE'] if 'GIỮ' in name else ['GỬI XE'], 'toc': None}[kind]
    with L['doc']: blade(kind, w - .32, bbg, bfg, words=words, font='inter' if kind != 'pho' else 'paytone')

# ---------------------------------------------------------------- 4 quán trong truyện
def lo_banh(w, L):
    """BÁNH MÌ CÔ BA — bảng đỏ cổ cao 1,5 m, chữ vàng viền nâu, ổ bánh mì 3D 1,7 m nằm vắt trên mép bảng,
    huy hiệu tròn "MÈO GIAO TẬN NƠI" in dấu chân mèo, hàng bóng đèn tròn ấm ở mép dưới."""
    x0, x1, z1 = .1, w - .1, 1.5; cx = w / 2
    with L['bang']:
        rect(x0, x1, 0, z1, M('#B8322A', .45), d=.1, bv=.03)
        frame(x0, x1, 0, z1, M('#F3E2B8', .45), t=.07, d=.12)
        frame(x0 + .12, x1 - .12, .12, z1 - .12, M('#E8B43A', .4, .4), t=.025, d=.115)
        bulbs(x0 + .2, x1 - .2, -.06, -.14, 15, '#FFD27A', .045)
        for sx in (x0 + .2, x1 - .2):   # hai ke sắt đỡ bảng
            boxab((sx - .02, -.12, -.25), (sx + .02, 0, -.02), M(C['iron'], .5, .6), 0)
    with L['chu']:
        txt('BÁNH MÌ CÔ BA', .62, (cx + .45, FR - .03, .96), lit('#F6C344'), 'paytone', w - 2.0, extrude=.03, shadow='#4A1A10', sh_off=(.03, .01, -.03))
        txt('Thịt nguội · Pa tê · Chả lụa · Trứng ốp la', .16, (cx + .45, FR - .03, .52), M('#FFF3D6', .5), 'inter_b', w - 2.2, extrude=.008)
        txt('TỪ 1990 · ĐT 0908 33 1990', .13, (cx + .45, FR - .03, .3), M('#F6C344', .5), 'inter_b', w - 2.6, extrude=.008)
    with L['hinh']:
        # huy hiệu tròn bên trái
        bx, bz = x0 + .72, .75
        disc(.6, (bx, FR - .05, bz), M('#F3E2B8', .5), d=.07, n=36)
        torus(.6, .035, (bx, FR - .09, bz), M('#E8B43A', .4, .4), rot=(math.pi / 2, 0, 0), n=36, m=6)
        disc(.5, (bx, FR - .09, bz), M('#B8322A', .45), d=.02, n=36)
        pm = M('#F6C344', .4)
        disc(.16, (bx, FR - .11, bz - .07), pm, d=.03, n=20, sz=.85)
        for a in (-55, -18, 18, 55): disc(.065, (bx + .2 * math.sin(math.radians(a)), FR - .11, bz + .1 + .08 * math.cos(math.radians(a))), pm, d=.03, n=14)
        txt('MÈO GIAO', .085, (bx, FR - .115, bz + .36), M('#FFF3D6', .5), 'inter_b', .6, extrude=.005)
        txt('TẬN NƠI', .085, (bx, FR - .115, bz - .36), M('#FFF3D6', .5), 'inter_b', .6, extrude=.005)
        # ổ bánh mì 1,7 m nằm vắt trên mép trên, nghiêng nhẹ, chìa ra trước
        crust = M('#D9963E', .55, sheen=.2); bx2 = cx + .55
        o = ball(.5, (bx2, -.3, z1 + .17), crust, (1.75, .42, .34), sub=3); o.rotation_euler = (0, -.06, 0)
        for k in range(5):       # năm vết khía bánh vàng nhạt trên lưng ổ
            e = ball(.13, (bx2 - .58 + k * .29, -.36, z1 + .3 - .018 * abs(k - 2)), M('#F5DFA8', .7), (1.0, .35, .22), sub=2); e.rotation_euler = (.5, -.06, .55)
        for sx in (-1, 1): ball(.07, (bx2 + sx * .82, -.3, z1 + .15), M('#B8742C', .6), (1.2, .9, .8), sub=2)
        for sx in (-1, 1): boxab((bx2 + sx * .5 - .03, -.2, z1 - .02), (bx2 + sx * .5 + .03, -.02, z1 + .08), M(C['iron'], .5, .6), 0)
    with L['doc']:
        x = w - .3
        _blade_frame(x, BZ0 + .25, BZ1 + .2, BOUT + .05, glow('#B8322A', .2, 1.2, .45), M('#F3E2B8', .45))
        yc = -(BOUT + .17) / 2
        o = ball(.3, (x, yc, BZ1 + .4), crust, (.38, 1.3, .4), sub=3); o.rotation_euler = (.12, 0, 0)
        for k in range(3): e = ball(.08, (x, yc - .22 + k * .22, BZ1 + .5), M('#F5DFA8', .7), (.5, .9, .3), sub=2); e.rotation_euler = (0, 0, .5)
        _blade_words(x, ['BÁNH', 'MÌ'], BZ1 - .25, .48, .3, M('#F6C344', .4), 'paytone', out=BOUT + .05)
        for side in (1, -1): txt('CÔ BA', .14, (x + side * .062, yc, BZ0 + .45), M('#FFF3D6', .5), 'inter_b', .5, rot=(math.pi / 2, 0, side * math.pi / 2), extrude=.006)

def cafe_may(w, L):
    """Cà Phê Mây — bảng hình đám mây trắng kem viền xanh trời, chữ Pacifico nâu cà phê; phin + ly 3D bốc khói,
    bảng treo hình ly trên tay sắt uốn; tối thì viền mây hắt sáng xanh."""
    cx = w / 2; m = M('#FBF6EA', .55); rim = M('#7FB7D9', .45)
    # đám mây: thân chữ nhật bo + 7 bướu tròn trên đỉnh, 2 bướu hai bên
    lobes = [(-.42, .55, .5), (-.28, .95, .55), (-.1, 1.12, .6), (.1, 1.1, .62), (.28, .98, .55), (.43, .58, .5)]
    with L['bang']:
        rect(.55, w - .55, .05, .95, m, d=.1, bv=.2)
        for fx, fz, r in lobes: disc(r, (cx + fx * (w - 1.0), -.05, fz), m, d=.1, n=36)
        for fx, fz, r in lobes: disc(r + .035, (cx + fx * (w - 1.0), -.015, fz), glow('#7FB7D9', .2, 2.4), d=.03, n=36)
        rect(.5, w - .5, .0, 1.0, glow('#7FB7D9', .2, 2.4), d=.03, bv=.25)
        bulbs(.7, w - .7, -.12, -.12, 13, '#FFE2A8', .035)
    with L['chu']:
        txt('Cà Phê Mây', 1.05, (cx + .4, FR - .08, .74), lit('#5A3420', .6), 'pacifico', w - 2.6, extrude=.03, shadow='#C9E4F2', sh_off=(.025, .012, -.025))
        txt('cà phê sữa đá · bạc xỉu · trà đá', .19, (cx + .4, FR - .08, .27), M('#3E7FAE', .5), 'inter_b', w - 3.0, extrude=.008)
        txt('ĐT 0938 06 2026', .11, (cx + .45, FR - .08, .14), M('#3E7FAE', .5), 'inter_b', 1.6, extrude=.006)
    with L['hinh']:
        # ly thủy tinh + phin nhôm đang nhỏ giọt, cao 0,9 m, đứng chìa ra trước bên trái
        gx, gy = .95, -.42
        cyl(.2, .42, (gx, gy, .32), M('#E9F2F4', .05, alpha=.55, coat=1), n=24, bv=.01, r2=.17)
        cyl(.18, .2, (gx, gy, .22), M('#5A3420', .4), n=20, bv=0, r2=.165)                   # cà phê
        cyl(.175, .1, (gx, gy, .37), M('#F1E2C4', .4), n=20, bv=0)                            # lớp sữa
        al = M('#DADFE2', .22, .9)                                                            # nhôm sáng
        cyl(.26, .025, (gx, gy, .545), al, n=24, bv=.004)                                     # đĩa phin
        cyl(.15, .2, (gx, gy, .66), al, n=24, bv=.01, r2=.13)                                 # thân phin thon
        cyl(.135, .03, (gx, gy, .775), al, n=24, bv=.008)                                     # nắp
        ball(.035, (gx, gy, .81), al, sub=1)                                                  # núm nắp
        for k in range(8): a = 2 * math.pi * k / 8; ball(.012, (gx + .15 * math.cos(a), gy + .15 * math.sin(a), .6), M('#9AA0A3', .3, .9), sub=1)
        ball(.03, (gx, gy, .5), M('#5A3420', .3), (1, 1, 1.4), sub=1)                         # giọt
        for k in range(3):
            curve([(gx - .08 + k * .08 + .04 * math.sin(j * 1.3 + k), gy, .9 + j * .08) for j in range(6)], .014, M('#FFFFFF', .6, alpha=.9))
        boxab((gx - .2, gy, -.01), (gx + .2, -.05, .02), M(C['iron'], .5, .6), 0)            # kệ đỡ
    with L['doc']:
        x = w - .35; arm = M('#2B2B2B', .5, .5); yc = -.62
        boxab((x - .02, -1.0, BZ1 - .02), (x + .02, 0, BZ1 + .02), arm, 0)                   # tay sắt
        for k in range(8): torus(.06, .01, (x, -.15 - k * .1, BZ1 - .07 + .02 * math.sin(k)), arm, rot=(0, math.pi / 2, 0), n=10, m=3)
        for dy in (-.25, .25): curve([(x, yc + dy, BZ1), (x, yc + dy * .8, BZ1 - .25)], .006, arm)
        # tấm gỗ hình ly cà phê có quai, treo hai xích
        mw = M('#8A5A30', .8)
        boxab((x - .04, yc - .32, BZ1 - 1.15), (x + .04, yc + .26, BZ1 - .25), mw, .1)
        torus(.15, .04, (x, yc + .32, BZ1 - .65), mw, rot=(0, math.pi / 2, 0), n=16, m=5)
        for side in (1, -1):
            txt('CÀ', .2, (x + side * .042, yc - .03, BZ1 - .5), M('#FBF6EA', .5), 'paytone', .5, rot=(math.pi / 2, 0, side * math.pi / 2), extrude=.006)
            txt('PHÊ', .2, (x + side * .042, yc - .03, BZ1 - .78), M('#FBF6EA', .5), 'paytone', .5, rot=(math.pi / 2, 0, side * math.pi / 2), extrude=.006)
            for k in range(3): curve([(x + side * .045, yc - .13 + k * .1 + .02 * math.sin(j), BZ1 - .2 + j * .07) for j in range(4)], .01, M('#FBF6EA', .6))

def tiem_xe(w, L):
    """SỬA XE HÙNG — tôn đen sơn chữ vàng khuôn (stencil), lốp xe thật treo góc trái, cờ lê + mỏ lết bắt chéo bên phải,
    bảng dọc vàng "VÁ XE" có hình lốp; tối có bóng đèn trần lồng sắt và đèn tuýp trên mép."""
    x0, x1, z1 = .1, w - .1, 1.35; cx = w / 2
    with L['bang']:
        corrugated(z1, x1 - x0, M('#2A2A2C', .55, .35), (cx, -.05, z1 / 2), rot=(0, math.pi / 2, math.pi / 2), period=.12, amp=.016)
        for zz in (0, z1): boxab((x0 - .03, -.11, zz - .03), (x1 + .03, 0, zz + .03), M('#F2B33D', .5, .2), 0)
        for k in range(int((x1 - x0) / .3)): box((.16, .012, .05), (x0 + .15 + k * .3, -.115, z1 - .1), M('#F2B33D' if k % 2 else '#2A2A2C', .5), 0, rot=(0, .7, 0))
        # đèn tuýp trên mép + bóng đèn lồng sắt
        cyl(.025, x1 - x0 - .6, (cx, -.2, z1 + .1), glow('#E8F4FF', .3, 3.0), rot=(0, math.pi / 2, 0), n=8, bv=0)
        boxab((x0 + .3, -.2, z1 + .05), (x0 + .32, 0, z1 + .07), M(C['iron'], .5, .6), 0); boxab((x1 - .32, -.2, z1 + .05), (x1 - .3, 0, z1 + .07), M(C['iron'], .5, .6), 0)
    with L['chu']:
        txt('SỬA XE HÙNG', .62, (cx + .1, FR - .04, .86), lit('#F2B33D'), 'stencil', w - 2.4, extrude=.006, shadow=None)
        txt('Vá xe · Thay nhớt · Bơm hơi · Sửa xe số, xe tay ga', .14, (cx + .1, FR - .04, .44), M('#F4F1E8', .55), 'inter_b', w - 2.6, extrude=.006)
        txt('ĐT 0909 55 7979 — làm nhanh, lấy liền', .12, (cx + .1, FR - .04, .22), M('#F2B33D', .55), 'inter_b', w - 3.0, extrude=.006)
    with L['hinh']:
        # lốp xe thật 0,6 m treo bằng dây chì góc trái, gai lốp
        tx, tz = x0 + .55, .55
        torus(.25, .08, (tx, -.28, tz), M('#1D1D1D', .85), rot=(math.pi / 2, 0, 0), n=28, m=10)
        for k in range(20):
            a = 2 * math.pi * k / 20; box((.045, .17, .03), (tx + .33 * math.cos(a), -.28, tz + .33 * math.sin(a)), M('#111111', .9), 0, rot=(0, -a, 0))
        disc(.17, (tx, -.28, tz), M('#C9CED0', .3, .8), d=.06, n=20)
        for k in range(6): a = 2 * math.pi * k / 6; box((.02, .02, .14), (tx + .08 * math.cos(a), -.32, tz + .08 * math.sin(a)), M('#9AA0A3', .3, .8), 0, rot=(0, -a + math.pi / 2, 0))
        curve([(tx, -.28, tz + .33), (tx, -.1, 1.25), (tx, -.02, 1.3)], .008, M(C['steel'], .3, .9))
        # cờ lê + mỏ lết bắt chéo bên phải, dài 1,0 m
        mx, mz = x1 - .62, .66; st = M('#C9CED0', .2, .95)
        for a, k in ((.75, 0), (-.75, 1)):
            box((.09, .04, 1.0), (mx, -.2 - k * .05, mz), st, .015, rot=(0, a, 0))
            ex, ez = .45 * math.sin(a), .45 * math.cos(a)
            torus(.1, .035, (mx + ex, -.2 - k * .05, mz + ez), st, rot=(math.pi / 2, 0, 0), n=16, m=5)
            box((.2, .045, .13), (mx - ex, -.2 - k * .05, mz - ez), st, .02, rot=(0, a, 0))
        # vết dầu loang (sơn) ở góc
        disc(.12, (x1 - .3, -.115, .15), M('#111111', .3, .3), d=.005, n=16, sx=1.6)
    with L['doc']:
        x = w - .3
        _blade_frame(x, BZ0 + .1, BZ1 + .1, BOUT, glow('#F2B33D', .15, 1.1, .5), M('#2A2A2C', .5))
        yc = -(BOUT + .12) / 2
        for side in (1, -1):
            torus(.17, .05, (x + side * .07, yc, BZ1 - .35), M('#1D1D1D', .85), rot=(0, math.pi / 2, 0), n=20, m=6)
        _blade_words(x, ['VÁ', 'XE'], BZ1 - .75, .38, .3, M('#1D1D1D', .5), 'stencil')

def tap_hoa_co_hai(w, L):
    """TẠP HÓA CÔ HAI — bảng trắng kiểu bảng được hãng nước tặng (dải đỏ trên in "NƯỚC MÁT · ĐÁ LẠNH", không nhãn thật),
    chữ xanh dương đậm, vỉ trứng 3D to ngồi vắt góc trên phải (gắn với túi trứng Thứ Ba), két nước ngọt góc trái."""
    x0, x1, z1 = .1, w - .1, 1.4; cx = w / 2
    with L['bang']:
        rect(x0, x1, 0, z1, glow('#F7F5EE', 0.0, .9, .45), d=.1, bv=.025)
        boxab((x0, -.105, z1 - .3), (x1, -.09, z1), M('#D3362B', .45), .01)
        boxab((x0, -.105, 0), (x1, -.09, .08), M('#1F4E9A', .45), .005)
        frame(x0, x1, 0, z1, M('#C9CED0', .3, .7), t=.035, d=.115)
    tx0, tx1 = x0 + 1.0, x1 - .15; tc = (tx0 + tx1) / 2
    with L['chu']:
        txt('NƯỚC MÁT · ĐÁ LẠNH · CÓ BÁN THẺ CÀO', .13, (cx - .3, FR - .04, z1 - .15), M('#FFFFFF', .4), 'inter_b', w - 1.8, extrude=.006)
        txt('TẠP HÓA CÔ HAI', .55, (tc, FR - .02, .72), lit('#1F4E9A', .8), 'paytone', tx1 - tx0, extrude=.03, shadow='#B9C8E2', sh_off=(.02, .008, -.02))
        txt('Gạo · Trứng · Nước mắm · Bánh kẹo', .15, (tc, FR - .02, .36), M('#D3362B', .45), 'inter_b', tx1 - tx0 - .3, extrude=.008)
        txt('ĐT 0283 22 4455', .11, (tc, FR - .02, .17), M('#1F4E9A', .45), 'inter_b', 1.6, extrude=.006)
    with L['hinh']:
        # vỉ trứng 3x4 quả (mỗi quả 0,16 m) ngồi vắt góc trên phải, nghiêng ra phố, nhô khỏi mép bảng
        ex, ez = x1 - .55, z1 + .05
        g = group('vi_trung', (ex, -.3, ez))
        g.rotation_euler = (math.radians(-60), 0, math.radians(-8))
        with at(g):
            boxab((-.42, -.05, -.32), (.42, .02, .32), M('#C9B48A', .9), .02)
            for i in range(4):
                for j in range(3):
                    ball(.1, (-.3 + i * .2, -.07, -.2 + j * .2), M('#F1E4CF' if (i + j) % 3 else '#E7C9A3', .5), (1, 1.25, 1), sub=2)
        for sx in (-.3, .3): boxab((ex + sx - .02, -.25, z1 - .05), (ex + sx + .02, 0, z1 + .02), M(C['iron'], .5, .6), 0)
        # két nước ngọt đỏ có 4 chai, góc trái, chìa ra trước
        kx = x0 + .5
        boxab((kx - .38, -.4, .12), (kx + .38, -.1, .5), M('#D3362B', .5), .02)
        txt('MÁT', .12, (kx, -.405, .31), M('#FFFFFF', .4), 'inter', .5, extrude=.004)
        for i in range(4):
            c = ['#3F8A5C', '#C8412F', '#F2B33D', '#3F8A5C'][i]
            cyl(.05, .36, (kx - .27 + i * .18, -.25, .66), M(c, .2, alpha=.9), n=10, bv=0)
            cyl(.022, .1, (kx - .27 + i * .18, -.25, .89), M(c, .2, alpha=.9), n=8, bv=0)
            cyl(.025, .02, (kx - .27 + i * .18, -.25, .95), M('#C9CED0', .3, .8), n=8, bv=0)
    with L['doc']:
        x = w - .3
        _blade_frame(x, BZ0, BZ1, BOUT, glow('#D3362B', .2, 1.3, .5), M('#F7F5EE', .45))
        yc = -(BOUT + .12) / 2
        for side in (1, -1): ball(.13, (x + side * .065, yc, BZ1 - .3), lit('#F1E4CF', .8), (.4, 1, 1.3), sub=2)
        _blade_words(x, ['TẠP', 'HÓA'], BZ1 - .72, .42, .32, M('#FFFFFF', .4), 'paytone')

HERO = {'lo_banh': (lo_banh, 'BÁNH MÌ CÔ BA', 5.2), 'cafe_may': (cafe_may, 'CÀ PHÊ MÂY', 6.0),
        'tiem_xe': (tiem_xe, 'SỬA XE HÙNG', 5.5), 'tap_hoa_co_hai': (tap_hoa_co_hai, 'TẠP HÓA CÔ HAI', 4.4)}

def make(key, w=None, loc=(0, 0, 0), explode=0.0, name=None):
    root = group(name or key, loc)
    L = Layers(root, explode)
    if key in HERO:
        fn, _, w0 = HERO[key]; fn(w or w0, L)
    else:
        generic(key, w or 4.0, L)
    return root
