"""Phác thảo G1 "Dấu vết khu phố" (Vũ Trụ Mark, Sang chọn 30/10/2026): hai đồ phẳng nhắc tới Mark học AI trong game.

P1  Tờ poster "Mark học AI" dán ở chân cầu thang Lô B chung cư (Thứ Năm): giấy 60 x 85 cm, bốn miếng băng keo,
    góc dưới phải quăn, hàng giấy xé ở chân (vài miếng đã bị xé, tức là hàng xóm có lấy địa chỉ).
T1  Ti vi CRT nhỏ treo giá sắt trong lò bánh Cô Ba: màn hình chiếu Bit hỏi "Hôm nay học gì về AI nè?".

Hình 2D trên poster và màn ti vi ghép từ hình Mark và Bit đã duyệt của markhocai.com (assets/mark-chao.svg, bit-giai-thich.svg,
logo.svg), không vẽ lại nhân vật. Ảnh nằm trong anh-2d/ (poster.png, man_tv.png), dựng bằng poster.html, man_tv.html.
Khối ti vi dựng bằng kit khu phố (tools/khu_pho/kit.py của repo game), phong cách D: khối cứng bevel 1–2 cm, màu ấm.

Chạy: pip install bpy==5.2.0 numpy
      python3 tools/dau_vet/dau_vet.py <repo game> <thư mục ra>          # bản phác: ảnh render, glb xem xoay, so_lieu.json
      python3 tools/dau_vet/dau_vet.py --game <repo game> assets/models/dau_vet  # bản game (Sang duyệt 31/10/2026)
Bản phác ra: poster.glb, ti_vi.glb, canh_so_co.glb (cả hai món, có Bơ đứng cạnh), anh/*.png, so_lieu.json.
Bản game ra: poster_mark.glb, ti_vi_bit.glb: bỏ bevel, không tường, không nhúng ảnh. Mặt giấy (mesh "giay") và màn
(mesh "man_hinh") được scripts/dau_vet_mark.gd dán ảnh poster.png / man_tv.png nằm cạnh glb.
Trang duyệt: https://claude.ai/artifact/PBBv3zEMstcgqE5SmuBYUN (nguồn ảnh 2D: /mnt/project-files/vu-tru-mark-dot-2/g1-dau-vet/anh-2d/).
"""
import sys, os, math, json
import numpy as np
import bpy

REPO = sys.argv[-2] if len(sys.argv) > 2 else '/home/claude/meo-giao-banh-mi'
OUT = sys.argv[-1] if len(sys.argv) > 2 else os.path.dirname(os.path.abspath(__file__))
HERE = os.path.dirname(os.path.abspath(__file__))
GAME = '--game' in sys.argv
sys.path.insert(0, os.path.join(REPO, 'tools/khu_pho'))
import kit
from kit import *

MAU = dict(vo_tv='#E3D6BC', vien_tv='#3A3631', num='#2B2925', sat='#4A4D52', bang_keo='#E9DDB8', tuong='#D9C9A8',
           tuong_bep='#EFE3CC', gach='#C9B79A')

PW, PH = .60, .85          # poster (m)
TW, TH, TD = .52, .42, .40  # ti vi: rộng, cao, sâu


def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    kit._MATS.clear(); kit.PARENT[0] = None


def anh_mat(ten_anh, emit=0.0, clip=False):
    """Vật liệu dán ảnh: alpha clip cho chỗ giấy xé, emission nhẹ cho màn ti vi."""
    m = bpy.data.materials.new('anh_' + ten_anh)
    m.use_nodes = True
    nt = m.node_tree; b = nt.nodes['Principled BSDF']
    im = nt.nodes.new('ShaderNodeTexImage'); im.image = bpy.data.images.load(os.path.join(REPO, 'assets/models/dau_vet', ten_anh) if GAME else os.path.join(HERE, 'anh-2d', ten_anh))
    nt.links.new(im.outputs['Color'], b.inputs['Base Color'])
    b.inputs['Roughness'].default_value = .85 if not emit else .35
    if clip:
        nt.links.new(im.outputs['Alpha'], b.inputs['Alpha'])
        try: m.surface_render_method = 'DITHERED'
        except Exception: pass
    if emit:
        nt.links.new(im.outputs['Color'], b.inputs['Emission Color']); b.inputs['Emission Strength'].default_value = emit
    return m


def tam_anh(name, w, h, mat, loc, rot=(math.pi / 2, 0, 0), cong=0.0):
    """Mặt phẳng có UV phủ trọn ảnh. cong > 0: uốn nhẹ góc dưới phải ra khỏi tường (giấy quăn)."""
    nx, ny = 6, 8
    V, F, UV = [], [], []
    for j in range(ny + 1):
        for i in range(nx + 1):
            u, v = i / nx, j / ny
            x, y = (u - .5) * w, (v - .5) * h
            z = cong * max(0.0, (u - .7) / .3) ** 2 * max(0.0, (.3 - v) / .3) ** 2
            V.append((x, y, z)); UV.append((u, v))
    for j in range(ny):
        for i in range(nx):
            a = j * (nx + 1) + i
            F.append((a, a + 1, a + nx + 2, a + nx + 1))
    o = mesh_obj(name, V, F, mat, loc, rot)
    uv = o.data.uv_layers.new(name='UV')
    for p in o.data.polygons:
        for li in p.loop_indices:
            uv.data[li].uv = UV[o.data.loops[li].vertex_index]
    return o


def poster(tach=0.0):
    """Tâm ở giữa tờ giấy, mặt giấy hướng -Y (ra ngoài tường), dán sát mặt tường y = 0."""
    g = group('poster', (0, 0, 0))
    with at(g):
        tam_anh('giay', PW, PH, anh_mat('poster.png', clip=True), (0, -.002 - tach * .3, 0), cong=.035)
        keo = M(MAU['bang_keo'], .6, alpha=.85)
        for sx, sz in ((-1, 1), (1, 1), (-1, -1), (1, -1)):
            if sx == 1 and sz == -1:
                continue                     # góc quăn bị bong keo
            k = box((.09, .002, .03), (sx * (PW / 2 - .02), -.004 - tach, sz * (PH / 2 - .015)), keo, 0, name='bang_keo')
            k.rotation_euler = (0, sx * sz * math.radians(35), 0)
    return g


def ti_vi(tach=0.0):
    """Ti vi đặt trên giá sắt bắt vào tường (tường ở y = +TD/2 + .06). Gốc ở đáy giá."""
    g = group('ti_vi', (0, 0, 0))
    vo = M(MAU['vo_tv'], .55); vien = M(MAU['vien_tv'], .5); num = M(MAU['num'], .45); sat = M(MAU['sat'], .5, .6)
    with at(g):
        # giá sắt chữ L: mặt đỡ + hai thanh chéo xuống tường
        box((TW * .8, TD * .9, .02), (0, .03, .01), sat, .004, name='gia_do')
        for sx in (-1, 1):
            box((.025, .025, .34), (sx * TW * .3, TD / 2 + .02 + tach * .4, -.15), sat, .004, name='thanh_tuong')
            cx = box((.02, .02, .40), (sx * TW * .3, .14 + tach * .2, -.11), sat, .003, name='thanh_cheo')
            cx.rotation_euler = (math.radians(-38), 0, 0)
        z0 = .02 + tach * .5
        # thân sau thuôn (đuôi bóng hình CRT) và khung trước
        box((TW * .78, TD * .55, TH * .78), (0, TD * .2 + tach * .4, z0 + TH * .45), vo, .03, name='duoi')
        box((TW, TD * .5, TH), (0, -TD * .2, z0 + TH / 2), vo, .03, name='than')
        # viền màn tối, màn hình ảnh Bit
        box((TW * .78, .02, TH * .74), (-TW * .07, -TD * .45 - tach, z0 + TH * .55), vien, .012, name='vien_man')
        tam_anh('man_hinh', TW * .7, TH * .66, anh_mat('man_tv.png', emit=1.2), (-TW * .07, -TD * .45 - .013 - tach * 1.6, z0 + TH * .55))
        # cột nút bên phải: hai núm xoay, loa sọc
        for k, zz in enumerate((.72, .52)):
            cyl(.028, .03, (TW * .4, -TD * .46 - tach, z0 + TH * zz), num, rot=(math.pi / 2, 0, 0), n=12, bv=.004, name='num')
        for k in range(4):
            box((.06, .006, .008), (TW * .4, -TD * .452 - tach, z0 + TH * (.12 + k * .06)), vien, 0, name='loa')
        # ăng-ten tai thỏ
        for sx in (-1, 1):
            a = cyl(.004, .32, (sx * .05, .02, z0 + TH + .14 + tach * .5), sat, n=6, bv=0, name='ang_ten')
            a.rotation_euler = (0, sx * math.radians(28), 0)
        ball(.025, (0, .02, z0 + TH + .01 + tach * .5), sat, (1.4, 1, .6), name='de_ang_ten')
    return g


# ---------------------------------------------------------------- chụp (giống sach_thang.py của C1)
def anh_sang(world='#F3EDE1'):
    sc = bpy.context.scene
    sc.render.engine = 'BLENDER_EEVEE_NEXT' if 'BLENDER_EEVEE_NEXT' in [e.identifier for e in bpy.types.RenderSettings.bl_rna.properties['engine'].enum_items] else 'BLENDER_EEVEE'
    sc.render.resolution_x = 900; sc.render.resolution_y = 900
    try: sc.eevee.taa_render_samples = 32
    except Exception: pass
    w = bpy.data.worlds.new('w'); sc.world = w; w.use_nodes = True
    w.node_tree.nodes['Background'].inputs[0].default_value = lin(world); w.node_tree.nodes['Background'].inputs[1].default_value = .45
    for loc, e, s in (((-2, -3, 3), 520, 2.5), ((3, -1, 2), 160, 3), ((0, 3, 2.5), 220, 2)):
        L = bpy.data.lights.new('L', 'AREA'); L.energy = e; L.size = s
        o = bpy.data.objects.new('L', L); o.location = loc; sc.collection.objects.link(o)
        d = -np.array(loc, float); o.rotation_euler = (math.atan2(math.hypot(d[0], d[1]), -d[2]), 0, math.atan2(d[1], d[0]) - math.pi / 2)
    try:
        sc.view_settings.view_transform = 'AgX'; sc.view_settings.look = 'AgX - Medium High Contrast'
    except Exception: pass
    box((8, 8, .01), (0, 0, -.005), M('#EAE2D2', .9), 0, name='san')


def chup(ten, tam, huong, xa, lens=60):
    sc = bpy.context.scene
    cam = bpy.data.cameras.new('c'); cam.lens = lens
    o = bpy.data.objects.new('cam', cam); sc.collection.objects.link(o); sc.camera = o
    h = np.array(huong, float); h /= np.linalg.norm(h)
    o.location = tuple(np.array(tam) + h * xa)
    d = -h; o.rotation_euler = (math.atan2(math.hypot(d[0], d[1]), -d[2]), 0, math.atan2(d[1], d[0]) - math.pi / 2)
    os.makedirs(os.path.join(OUT, 'anh'), exist_ok=True)
    sc.render.filepath = os.path.join(OUT, 'anh', ten + '.png')
    bpy.ops.render.render(write_still=True)
    bpy.data.objects.remove(o, do_unlink=True)


def xuat_glb(ten):
    bpy.ops.object.select_all(action='DESELECT')
    for o in bpy.context.scene.objects:
        if o.name != 'san' and o.type in ('MESH', 'FONT', 'EMPTY', 'CURVE'): o.select_set(True)
    bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, ten), use_selection=True, export_apply=True, export_yup=True)


def dem_tam_giac(bo_bevel=True):
    for o in bpy.context.scene.objects:
        for md in list(o.modifiers):
            if bo_bevel and md.type == 'BEVEL': o.modifiers.remove(md)
    dg = bpy.context.evaluated_depsgraph_get(); n = 0
    for o in bpy.context.scene.objects:
        if o.type == 'MESH' and o.name not in ('san', 'tuong'):
            me = bpy.data.meshes.new_from_object(o.evaluated_get(dg)); n += sum(len(p.vertices) - 2 for p in me.polygons)
    return n


def tuong(w, h, mau, y=0.0, x=0.0):
    return box((w, .1, h), (x, y + .05, h / 2), M(mau, .9), 0, name='tuong')


def bo(loc, rot_deg):
    bpy.ops.import_scene.gltf(filepath=os.path.join(REPO, 'assets/models/bo.glb'))
    for o in [o for o in bpy.context.selected_objects if o.parent is None]:
        o.location = loc; o.rotation_euler = (math.pi / 2, 0, math.radians(rot_deg))


def main():
    so = {}
    # P1 poster: trên mảng tường, đáy giấy cao 0,9 m (mắt Bơ nhìn lên thấy, người lớn đọc ngang tầm)
    reset(); anh_sang(); tuong(1.6, 2.2, MAU['tuong']); p = poster(); p.location = (0, 0, .9 + PH / 2)
    xuat_glb('poster.glb')
    tam = (0, 0, 1.32)
    chup('p_truoc', tam, (0, -1, .05), 2.4, 50)
    chup('p_ngang', tam, (1, -.25, .05), 2.4, 50)
    chup('p_ba_phan_tu', tam, (.7, -1, .2), 2.6, 50)
    chup('p_can_goc', (.24, 0, 1.0), (.5, -1, .1), .9, 60)
    reset(); anh_sang(); tuong(1.6, 2.2, MAU['tuong']); p = poster(tach=.08); p.location = (0, 0, .9 + PH / 2)
    chup('p_tach', tam, (.8, -1, .25), 2.8, 50)
    reset(); p = poster(); so['poster'] = dict(tam_giac_ban_game=dem_tam_giac(), kich_thuoc_m=[PW, PH], anh='poster.png 840x1188, alpha clip')

    # T1 ti vi: giá bắt vào tường bếp, đáy giá cao 1,9 m (trên đầu Cô Ba, nhìn thấy qua tủ kính)
    reset(); anh_sang(); tuong(1.6, 2.6, MAU['tuong_bep'], y=TD / 2 + .06); t = ti_vi(); t.location = (0, 0, 1.9)
    xuat_glb('ti_vi.glb')
    tam = (0, 0, 2.12)
    chup('t_truoc', tam, (0, -1, -.05), 2.3, 50)
    chup('t_ngang', tam, (1, -.1, -.05), 2.3, 50)
    bpy.data.objects['tuong'].hide_render = True  # nhìn sau thì bỏ tường
    chup('t_sau', tam, (-.5, .9, .15), 2.3, 50)
    bpy.data.objects['tuong'].hide_render = False
    chup('t_ba_phan_tu', tam, (.7, -1, -.3), 2.4, 50)
    reset(); anh_sang(); t = ti_vi(tach=.1); t.location = (0, 0, 1.9)
    chup('t_tach', (0, -.08, 2.12), (.8, -1, .1), 2.8, 50)
    reset(); t = ti_vi(); so['ti_vi'] = dict(tam_giac_ban_game=dem_tam_giac(), kich_thuoc_m=[TW, TH, TD], anh='man_tv.png 640x480, emission 1,2')

    # cảnh so cỡ: Bơ đứng dưới poster
    reset(); anh_sang('#EFE7D8'); tuong(3.2, 2.6, MAU['tuong'])
    p = poster(); p.location = (-.4, 0, .9 + PH / 2)
    bo((.25, -.5, 0), 200)
    xuat_glb('canh_so_co.glb')
    chup('so_co', (0, 0, .95), (.25, -1, .3), 3.8, 45)
    json.dump(so, open(os.path.join(OUT, 'so_lieu.json'), 'w'), indent=1, ensure_ascii=False)
    print('xong', so)


def xuat_game():
    """Bản game: bỏ bevel, gộp không cần (mỗi món vài mesh, vật liệu màu trơn), ảnh nạp riêng trong Godot."""
    os.makedirs(OUT, exist_ok=True)
    for ten, dung in (('poster_mark.glb', poster), ('ti_vi_bit.glb', ti_vi)):
        reset(); dung()
        for o in bpy.context.scene.objects:
            for md in list(o.modifiers):
                if md.type == 'BEVEL': o.modifiers.remove(md)
        print(ten, dem_tam_giac(), 'tam giác')
        # gộp phần khối thành một mesh "vo" (ít lệnh vẽ), giữ riêng mesh có ảnh
        khoi = [o for o in bpy.context.scene.objects if o.type == 'MESH' and o.name not in ('giay', 'man_hinh')]
        bpy.ops.object.select_all(action='DESELECT')
        for o in khoi:
            o.select_set(True)
        bpy.context.view_layer.objects.active = khoi[0]
        bpy.ops.object.convert(target='MESH')
        bpy.ops.object.join()
        khoi[0].name = 'vo'
        bpy.ops.object.select_all(action='SELECT')
        bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, ten), use_selection=True, export_apply=True, export_yup=True,
                                  export_image_format='NONE')


if __name__ == '__main__':
    xuat_game() if GAME else main()
