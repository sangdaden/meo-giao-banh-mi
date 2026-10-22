"""Đồ cầm tay của người qua đường (trang P3 "Người qua đường và xe ra vào", Sang duyệt 22/10).
Cùng hình SDF với p3nguoi.build của trang phác thảo, dựng quanh gốc là chỗ bàn tay cầm, gắn bằng Nguoi.attach / hold.
Dùng chung bộ dựng của do_cam_g9.py (một mesh, một vật liệu, màu đỉnh).

Dùng: python3 tools/khu_pho/do_cam_p3.py assets/models/nguoi [ten,ten]
Trục (như three/Godot): x trái của người cầm, y lên, z ra trước. Mét thật.
  dien_thoai  điện thoại (Chị Vy nhìn hai tay, Anh Đạt áp tai), màn hình quay về -z
  ly_tra_da   ly trà đá nhựa (ngồi ghế nhựa)            bang_ve_so  bảng vé số kẹp tay trái (Cô Tám)
  xap_ve      xấp vé xòe chìa ra mời (tay phải)          hop_com     hộp cơm xốp mở nắp (Chú Bảy, tay trái)
  dua         đôi đũa (tay phải)                          goi_hang    thùng hàng các-tông (Anh Đạt)
  tui_che_dau túi xách giơ lên đầu che mưa (Chị Vy, gắn giữa hai tay)
"""
import sys
import os
import json
import math
import numpy as np
import bpy
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import do_cam_g9 as G  # noqa: E402
from sdflib import v, roundcone, smax  # noqa: E402
from nguoi import box  # noqa: E402

G.COL.update(dt='#2E3640', dt2='#7FB3D9', trada='#C98A3A', lynhua='#D8E6E4', veso='#2E7C80', ve='#F4E6B0', ve2='#E58AA0',
             hopcom='#F4F1EA', dua='#F2F0EA', goi='#C99A5A', tuixach='#B8673A')


def dien_thoai():
    return [(lambda p: box(p, v(0, 0, 0), v(.04, .078, .007), .006), 'dt'),
            (lambda p: box(p, v(0, .002, -.006), v(.034, .068, .002), .002), 'dt2')]


def ly_tra_da():
    a, b = v(0, -.05, 0), v(0, .07, 0)
    return [(lambda p: roundcone(p, a, b, .036, .044), 'lynhua'),
            (lambda p: smax(roundcone(p, a, b, .0375, .0455), p[..., 1] - .045, .002), 'trada')]


def bang_ve_so():
    c = v(0, .03, 0)
    out = [(lambda p: box(p, c, v(.11, .15, .006), .006), 'veso')]
    for i in range(4):
        out.append(((lambda i: lambda p: box(p, c + v(0, .1 - i * .066, .009), v(.095, .026, .003), .002))(i), 've' if i % 2 else 've2'))
    return out


def xap_ve():
    out = []
    for i in range(4):
        ang = -.5 + i * .33
        out.append(((lambda ang, i: lambda p: box(p, v(math.sin(ang) * .05, .035 + math.cos(ang) * .03, .004 * i), v(.024, .045, .002), .002))(ang, i),
                    've' if i % 2 else 've2'))
    return out


def hop_com():
    return [(lambda p: smax(box(p, v(0, 0, 0), v(.085, .032, .065), .01), -box(p, v(0, .02, 0), v(.075, .03, .055), .008), .004), 'hopcom'),
            (lambda p: box(p, v(0, .06, -.07), v(.085, .06, .008), .008), 'hopcom')]


def dua():
    return [(lambda p: np.minimum(roundcone(p, v(0, 0, 0), v(.08, -.05, .1), .004, .003),
                                  roundcone(p, v(.01, 0, 0), v(.09, -.04, .1), .004, .003)), 'dua')]


def goi_hang():
    return [(lambda p: box(p, v(0, 0, 0), v(.12, .09, .1), .008), 'goi')]


def tui_che_dau():
    return [(lambda p: box(p, v(0, 0, 0), v(.15, .045, .1), .025), 'tuixach')]


# tên: (hàm, số tam giác sau giảm lưới, bước lưới)
G.DO = dict(dien_thoai=(dien_thoai, 100, .002), ly_tra_da=(ly_tra_da, 250, .004), bang_ve_so=(bang_ve_so, 300, .002),
            xap_ve=(xap_ve, 160, .0015), hop_com=(hop_com, 300, .003), dua=(dua, 80, .0015), goi_hang=(goi_hang, 120, .005),
            tui_che_dau=(tui_che_dau, 160, .005))

if __name__ == '__main__':
    out = sys.argv[1] if len(sys.argv) > 1 else 'assets/models/nguoi'
    names = sys.argv[2].split(',') if len(sys.argv) > 2 else list(G.DO)
    os.makedirs(out, exist_ok=True)
    rep = {}
    for n in names:
        ob, tris = G.build(n)
        path = os.path.join(out, n + '.glb')
        bpy.ops.export_scene.gltf(filepath=path, use_selection=True, export_yup=True, export_vertex_color='ACTIVE',
                                  export_normals=True, export_texcoords=False, export_materials='EXPORT', export_animations=False)
        rep[n] = dict(tris=tris, kb=os.path.getsize(path) // 1024)
    print(json.dumps(rep))
