"""Quầy gỗ cỡ người của Cô Ba và dao thái sửa lại (trang Cô Ba đứng bếp, Sang duyệt 21/10/2026). Dùng: python quay_ba.py <outdir> [--export]"""
# Cần pk.py, dscene.py, sdflib.py của bộ dựng phong cách D (/mnt/project-files/meo-3d/style-d) và pip bpy.
import sys, math
import pk, dscene as D
from pk import M, box, cyl, tex_mat
PI = math.pi

def c_quay(out):
    wood = tex_mat('go_quay', 'wood', '#C99B62', '#B0824C', 3)
    dark = M('#8F6A3D', 'wood')
    pk.TARGET.update(quay_ba=1400, khan_ca_ro=1200)
    pk.item('quay_ba')
    # mặt quầy 0,62 × 0,36 (kê sát tường phải, cạnh bàn nguyên liệu), cao 0,85; gờ trước dày hơn
    box((.62, .36, .04), (0, 0, .83), wood, .012)
    box((.62, .03, .06), (0, -.17, .80), dark, .008)
    # 4 chân + kệ dưới có ván
    for x in (-.27, .27):
        for y in (-.15, .15): box((.05, .05, .80), (x, y, .40), dark, .008)
    box((.56, .31, .025), (0, 0, .16), wood, .008)
    # vách sau che kệ dưới, 2 ngăn hộc phía trước
    box((.56, .02, .62), (0, .16, .47), wood, .006)
    for x in (-.14, .14):
        box((.26, .02, .16), (x, -.165, .70), M('#B98552', 'wood'), .006)
        cyl(.012, .02, (x, -.18, .70), M('#3A2E22', 'metal'), .003, rot=(PI / 2, 0, 0), n=16)
    # đồ dưới kệ: bao bột và rổ
    box((.2, .16, .2), (-.14, .0, .27), M('#EDE3CC', 'cloth'), .03)
    cyl(.09, .1, (.15, .0, .225), M('#C9A26A', 'wood'), .01, n=24)
    # khăn chung mesh với quầy
    # khăn ca rô đỏ trắng vắt mép trước: một tấm trên mặt + một tấm thả xuống
    red, white = M('#C8412F', 'cloth'), M('#F6EFE2', 'cloth')
    for i in range(4):
        for j in range(3):
            c = red if (i + j) % 2 == 0 else white
            box((.04, .04, .006), (.10 + i * .04, -.13 + j * .04, .853), c, .002)
            box((.04, .006, .04), (.10 + i * .04, -.19, .83 - j * .04), c, .002)
    pk.frame_and_render(out, 'p_quay')

def c_dao(out):
    # Dao thái nằm phẳng: lưỡi và cán cùng một trục (bản cũ lưỡi lệch khỏi cán, Sang báo 21/10)
    pk.item('dao')
    blade = M('#D3DBDA', 'metal')
    box((.2, .048, .004), (.05, 0, .011), blade, .0015)
    box((.012, .05, .006), (-.052, 0, .011), M('#B9C1C0', 'metal'), .002)
    box((.11, .026, .022), (-.113, .006, .011), M('#2B2726', 'plastic'), .008)
    for k in (-1, 1): cyl(.004, .024, (-.113 + k * .03, .006, .011), M('#C9C3B3', 'metal'), 0, n=12)

if __name__ == '__main__':
    out = sys.argv[1]; EXP = '--export' in sys.argv
    if EXP: pk.frame_and_render = lambda *a, **k: None
    for c in (c_quay, c_dao):
        pk._mats.clear(); pk.sc = D.reset(); pk.item(None); c(out)
        if EXP: print(pk.export_items(out))
