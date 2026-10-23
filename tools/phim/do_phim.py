"""3 đồ mới cho phim mở đầu và cảnh kết tuần (C1, trang phác thảo Sang duyệt 23/10/2026), dựng thẳng bằng bpy, phong cách D.
  khan_cam   khăn đỏ của Bơ lúc chưa quàng: Cô Ba vắt trên hai tay (mở đầu M4). Gốc ở giữa hai tay, khăn cao 0,32 m trên gốc.
  gio_ngu    giỏ mây lót gối caro, chỗ Bơ ngủ cạnh lò (kết tuần K6, K8)
  bang_tuan  bảng gỗ "Tuần của Bơ" treo tường tiệm (K5): 7 khung ảnh, móc huy chương, 2 móc treo túi. Tâm bảng cao 1,3 m.
             Mặt ảnh là các mesh riêng tên AnhT2 … AnhCN (scripts/phim/bang_tuan.gd thay ảnh người chơi chụp vào).
Chạy:  python3 tools/phim/do_phim.py assets/models/phim
Cần:   pip install bpy pillow numpy
"""
import sys
import os
import math
import tempfile
import bpy
import bmesh
from mathutils import Vector
from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0, os.path.join(ROOT, 'tools', 'dong_tac_bo'))
from scene import mat  # noqa: E402  vật liệu Principled theo mã màu (cùng bộ với phác thảo G2)

OUT = sys.argv[1]
os.makedirs(OUT, exist_ok=True)
TMP = tempfile.mkdtemp()
FONT = os.path.join(ROOT, 'assets', 'fonts', 'Baloo2-ExtraBold.ttf')
PARTS = {}


def box(name, size, loc, color, rough=.85, bevel=.01, rz=0.0, emit=0.):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc, rotation=(0, 0, math.radians(rz)))
    o = bpy.context.active_object
    o.name = name
    o.scale = size
    bpy.ops.object.transform_apply(scale=True)
    if bevel:
        b = o.modifiers.new('Bo', 'BEVEL')
        b.width = bevel
        b.segments = 2
    o.data.materials.append(mat(name, color, rough=rough, emit=emit))
    return o


def tris(objs):
    n = 0
    dg = bpy.context.evaluated_depsgraph_get()
    for o in objs:
        me = o.evaluated_get(dg).to_mesh()
        n += sum(len(p.vertices) - 2 for p in me.polygons)
        o.evaluated_get(dg).to_mesh_clear()
    return n


def obj_from(name, bm, m):
    me = bpy.data.meshes.new(name); bm.to_mesh(me); bm.free()
    o = bpy.data.objects.new(name, me); bpy.context.scene.collection.objects.link(o)
    o.data.materials.append(m)
    for p in me.polygons: p.use_smooth = True
    return o


def ribbon(name, path, width, thick, m, seg_w=3):
    """Dải vải theo đường path [(x,y,z)], bề ngang width nằm theo pháp tuyến ngang của đường, có độ dày."""
    bm = bmesh.new()
    pts = [Vector(p) for p in path]
    rows = []
    for i, p in enumerate(pts):
        t = (pts[min(i + 1, len(pts) - 1)] - pts[max(i - 1, 0)]).normalized()
        side = t.cross(Vector((0, 0, 1)))
        if side.length < .1: side = Vector((1, 0, 0))
        side.normalize(); up = side.cross(t).normalized()
        row = []
        for j in range(seg_w + 1):
            u = (j / seg_w - .5) * width
            for k in (-.5, .5):
                row.append(bm.verts.new(p + side * u + up * thick * k))
        rows.append(row)
    for a, b in zip(rows, rows[1:]):
        for j in range(seg_w):
            for k in (0, 1):
                i0, i1 = j * 2 + k, (j + 1) * 2 + k
                f = [a[i0], a[i1], b[i1], b[i0]]
                bm.faces.new(f if k else f[::-1])
        for j in (0, seg_w):
            f = [a[j * 2], a[j * 2 + 1], b[j * 2 + 1], b[j * 2]]
            bm.faces.new(f if j else f[::-1])
    for r in (rows[0], rows[-1]):
        try: bm.faces.new([r[j * 2] for j in range(seg_w + 1)][::-1] + [r[j * 2 + 1] for j in range(seg_w + 1)])
        except Exception: pass
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return obj_from(name, bm, m)


def khan_cam():
    red = mat('KhanDo', '#C8412F', rough=.9, sheen=1)
    cream = mat('SocKem', '#FBE6C8', rough=.9, sheen=1)
    # dải khăn dài 0,62 m rộng 7 cm vắt qua hai cẳng tay đặt ngang (hai tay cách 0,22 m): rủ võng ở giữa, hai đầu buông
    path = []
    for i in range(29):
        u = i / 28
        x = -.31 + u * .62
        if abs(x) <= .11:
            z = -.035 * (1 - (x / .11) ** 2)           # võng giữa hai tay
        else:
            d = abs(x) - .11
            z = -d * 1.35 - .01 * math.sin(d * 25)      # đầu khăn buông chéo xuống, gợn nhẹ
            x = math.copysign(.11 + d * .45, x)
        path.append((x, .012 * math.sin(u * 7), z))
    k = ribbon('Khan', path, .07, .012, red)
    out = [k]
    PARTS['khan_cam'] = [('Thân khăn', 'dải vải dài 62 cm, rộng 7 cm, dày 1,2 cm; võng 3,5 cm giữa hai tay, hai đầu buông', '#C8412F', 'vải nỉ mờ (Roughness .9, Sheen 1)')]
    for sgn in (-1, 1):
        for j, (i0, i1) in enumerate(((2, 4), (5, 6)) if sgn < 0 else ((22, 23), (24, 26))):
            o = ribbon(f'Soc{sgn}{j}', path[i0:i1 + 1], .072, .0135, cream); out.append(o)
        # tua rua: 5 sợi ở đầu khăn
        e = Vector(path[0 if sgn < 0 else -1])
        for f in range(5):
            bpy.ops.mesh.primitive_cylinder_add(vertices=5, radius=.0035, depth=.035, location=e + Vector((0, -.028 + f * .014, -.016)))
            o = bpy.context.active_object; o.name = f'Tua{sgn}{f}'; o.data.materials.append(red); out.append(o)
    for o in out:
        o.location.z += .32
    PARTS['khan_cam'] += [('Sọc kem ×4', 'hai sọc 1,3 cm gần mỗi đầu, như khăn Bơ đang đeo', '#FBE6C8', 'vải'),
                          ('Tua rua ×10', '5 sợi dài 3,5 cm mỗi đầu', '#C8412F', 'sợi len')]
    return out


def gio_ngu():
    may = mat('May', '#B9864E', rough=.85)
    may2 = mat('MayDam', '#8E5F33', rough=.85)
    cush = mat('Goi', '#E9DCC0', rough=.95, sheen=1)
    check = mat('Caro', '#C8412F', rough=.95, sheen=1)
    out = []
    # thân giỏ: ống tròn Ø52 cm cao 15 cm, thành dày 2 cm, đan mây (vạch dọc bằng 24 nan nổi)
    bpy.ops.mesh.primitive_cylinder_add(vertices=24, radius=.26, depth=.15, location=(0, 0, .075))
    o = bpy.context.active_object; o.name = 'ThanGio'; o.data.materials.append(may)
    sol = o.modifiers.new('Day', 'SOLIDIFY'); sol.thickness = .02
    bm = bmesh.new(); bm.from_mesh(o.data)
    bmesh.ops.delete(bm, geom=[f for f in bm.faces if f.normal.z > .9], context='FACES')
    bm.to_mesh(o.data); bm.free(); out.append(o)
    for i in range(24):
        a = i / 24 * math.tau
        bpy.ops.mesh.primitive_cylinder_add(vertices=4, radius=.006, depth=.14, location=(math.cos(a) * .272, math.sin(a) * .272, .075))
        n = bpy.context.active_object; n.name = f'Nan{i}'; n.data.materials.append(may2); out.append(n)
    for z in (.04, .1):
        bpy.ops.mesh.primitive_torus_add(major_radius=.27, minor_radius=.006, major_segments=32, minor_segments=4, location=(0, 0, z))
        n = bpy.context.active_object; n.name = f'Dai{z}'; n.data.materials.append(may2); out.append(n)
    bpy.ops.mesh.primitive_torus_add(major_radius=.265, minor_radius=.02, major_segments=32, minor_segments=8, location=(0, 0, .15))
    r = bpy.context.active_object; r.name = 'Vanh'; r.data.materials.append(may2); out.append(r)
    # gối nệm phồng + khăn caro gấp vắt một bên
    bpy.ops.mesh.primitive_uv_sphere_add(segments=20, ring_count=8, radius=.24, location=(0, 0, .085))
    g = bpy.context.active_object; g.name = 'Goi'; g.scale = (1, 1, .22); g.data.materials.append(cush); out.append(g)
    cm = mat('CaroTex', '#FFFFFF', rough=.95, sheen=1)
    img = Image.new('RGB', (64, 64), '#F3E7D0'); d = ImageDraw.Draw(img)
    for i in range(0, 64, 16):
        d.rectangle([i, 0, i + 6, 63], fill='#C8412F'); d.rectangle([0, i, 63, i + 6], fill='#C8412F')
    p = f'{TMP}/caro.png'; img.save(p)
    N = cm.node_tree.nodes; t = N.new('ShaderNodeTexImage'); t.image = bpy.data.images.load(p); t.interpolation = 'Closest'
    cm.node_tree.links.new(t.outputs[0], N['Principled BSDF'].inputs['Base Color'])
    path = [(-.05 + .0 * i, -.16 + i * .02, .13 + .02 * math.sin(i / 4)) for i in range(5)] + [(-.05, -.07 + i * .05, .14 + .01 * i) for i in range(3)] + \
           [(-.05, .2 + i * .03, .16 - .04 * i) for i in range(1, 4)]
    k = ribbon('KhanCaro', path, .2, .015, cm, seg_w=4)
    bpy.ops.object.select_all(action='DESELECT'); k.select_set(True); bpy.context.view_layer.objects.active = k
    bpy.ops.object.mode_set(mode='EDIT'); bpy.ops.mesh.select_all(action='SELECT'); bpy.ops.uv.cube_project(cube_size=.06); bpy.ops.object.mode_set(mode='OBJECT')
    out.append(k)
    PARTS['gio_ngu'] = [('Thân giỏ', 'ống Ø52 cm cao 15 cm, thành 2 cm, không nắp', '#B9864E', 'mây (Roughness .85)'),
                        ('Nan dọc ×24 + 2 đai', 'nan Ø1,2 cm nổi ngoài thân; 2 đai ngang ở 4 và 10 cm', '#8E5F33', 'mây sẫm'),
                        ('Vành miệng', 'ống tròn Ø4 cm quấn mép giỏ', '#8E5F33', 'mây sẫm'),
                        ('Gối nệm', 'đệm phồng Ø48 cm dày 10 cm', '#E9DCC0', 'vải bông'),
                        ('Khăn caro', 'khăn 20 cm vắt qua giỏ, caro đỏ kem (texture 64 px)', '#C8412F', 'vải')]
    return out


def bang_tuan():
    wood = mat('Go', '#9A6A3E', rough=.8)
    wood2 = mat('GoDam', '#6E4626', rough=.8)
    brass = mat('Dong', '#C9A04A', rough=.4, metal=1)
    out = []
    W, H = .96, .62
    # tấm gỗ + khung viền, treo bằng dây thừng
    out.append(box('Tam', (W, .025, H), (0, 0, 0), '#9A6A3E', bevel=.008))
    for x, z, sx, sz in ((0, H / 2, W + .04, .04), (0, -H / 2, W + .04, .04), (W / 2, 0, .04, H), (-W / 2, 0, .04, H)):
        out.append(box('Vien', (sx, .04, sz), (x, -.008, z), '#6E4626', bevel=.008))
    # tiêu đề sơn tay (texture) dải trên
    img = Image.new('RGB', (512, 64), '#F3E2BE'); d = ImageDraw.Draw(img)
    f = ImageFont.truetype(FONT, 46); txt = 'TUẦN CỦA BƠ'
    w = d.textlength(txt, font=f); d.text(((512 - w) / 2, -6), txt, font=f, fill='#B13A2A')
    tp = f'{TMP}/bang_tuan_chu.png'; img.save(tp)
    tm = mat('Chu', '#FFFFFF', rough=.9); N = tm.node_tree.nodes; t = N.new('ShaderNodeTexImage'); t.image = bpy.data.images.load(tp)
    tm.node_tree.links.new(t.outputs[0], N['Principled BSDF'].inputs['Base Color'])
    bpy.ops.mesh.primitive_plane_add(size=1, location=(0, -.0135, H / 2 - .085), rotation=(math.pi / 2, 0, 0))
    o = bpy.context.active_object; o.name = 'TieuDe'; o.scale = (.6, .075, 1); o.data.materials.append(tm); out.append(o)
    # 7 khung ảnh: hàng trên T2 T3 T4 T5, hàng dưới T6 T7 CN (CN ở giữa có móc huy chương ngay trên)
    days = [('T2', '#F2B45A'), ('T3', '#9CC27A'), ('T4', '#7FA6C9'), ('T5', '#C99A6B'), ('T6', '#E58A5C'), ('T7', '#E7C35A'), ('CN', '#B784C9')]
    pos = [(-.33, .1), (-.11, .1), (.11, .1), (.33, .1), (-.26, -.15), (0, -.15), (.26, -.15)]
    big = ImageFont.truetype(FONT, 40)
    for (dname, col), (x, z) in zip(days, pos):
        out.append(box('Khung' + dname, (.19, .02, .15), (x, -.018, z), '#FBF3E2', bevel=.004))
        im = Image.new('RGB', (128, 96), col); dd = ImageDraw.Draw(im)
        dd.ellipse([70, 50, 118, 92], fill='#E8913A'); dd.text((8, 2), dname, font=big, fill='#FFFFFF')
        ip = f'{TMP}/anh_{dname}.png'; im.save(ip)
        am = mat('Anh' + dname, '#FFFFFF', rough=.4); N = am.node_tree.nodes; t = N.new('ShaderNodeTexImage'); t.image = bpy.data.images.load(ip)
        am.node_tree.links.new(t.outputs[0], N['Principled BSDF'].inputs['Base Color'])
        bpy.ops.mesh.primitive_plane_add(size=1, location=(x, -.0285, z), rotation=(math.pi / 2, 0, 0))
        o = bpy.context.active_object; o.name = 'Anh' + dname; o.scale = (.16, .12, 1); o.data.materials.append(am); out.append(o)
        # kẹp gỗ trên đầu ảnh
        out.append(box('Kep' + dname, (.018, .012, .04), (x, -.033, z + .07), '#6E4626', bevel=.003))
    # móc huy chương (đồng) trên khung CN, 2 móc treo túi dưới đáy bảng
    for nm, x, z in (('MocHuyChuong', 0, -.05), ('MocTui1', -.2, -H / 2 - .01), ('MocTui2', .2, -H / 2 - .01)):
        bpy.ops.mesh.primitive_torus_add(major_radius=.016, minor_radius=.004, major_segments=12, minor_segments=4, location=(x, -.04, z - .012), rotation=(0, math.pi / 2, 0))
        o = bpy.context.active_object; o.name = nm; o.data.materials.append(brass); out.append(o)
        bpy.ops.mesh.primitive_cylinder_add(vertices=6, radius=.005, depth=.04, location=(x, -.025, z + .006), rotation=(math.pi / 2, 0, 0))
        o = bpy.context.active_object; o.name = nm + 'Chot'; o.data.materials.append(brass); out.append(o)
    # dây treo
    bpy.ops.mesh.primitive_torus_add(major_radius=.32, minor_radius=.006, major_segments=24, minor_segments=4, location=(0, 0, H / 2 + .02), rotation=(math.pi / 2, 0, 0))
    o = bpy.context.active_object; o.name = 'DayTreo'; o.scale = (1, .45, 1); o.data.materials.append(mat('Thung', '#8A5A3A', rough=.9)); out.append(o)
    bm = bmesh.new(); bm.from_mesh(o.data); bmesh.ops.delete(bm, geom=[v for v in bm.verts if v.co.y < .02], context='VERTS'); bm.to_mesh(o.data); bm.free()
    for o in out:
        o.location.z += 1.3   # tâm bảng cao 1,3 m trên sàn (đáy 0,99 m: túi treo vừa tầm Bơ đứng trên ghế)
    PARTS['bang_tuan'] = [('Tấm gỗ + viền', 'tấm 96×62 cm dày 2,5 cm, viền gỗ sẫm 4 cm', '#9A6A3E', 'gỗ (Roughness .8)'),
                          ('Tiêu đề', 'dải sơn tay "TUẦN CỦA BƠ", phông Baloo 2, texture 512×64', '#B13A2A', 'sơn'),
                          ('Khung ảnh ×7', 'nền giấy kem 19×15 cm, ảnh 16×12 cm, kẹp gỗ trên; ảnh = texture 256×192 lấy từ ảnh người chơi chụp mỗi ngày (chưa chụp thì ảnh vẽ sẵn)', '#FBF3E2', 'giấy ảnh bóng nhẹ'),
                          ('Móc huy chương', 'khoen đồng Ø3,2 cm ngay trên ảnh CN: huy chương Hội mèo treo vào đây', '#C9A04A', 'kim loại'),
                          ('Móc treo túi ×2', 'khoen đồng dưới đáy bảng: túi bánh Bơ treo bên trái', '#C9A04A', 'kim loại'),
                          ('Dây treo', 'dây thừng vòng qua đinh', '#8A5A3A', 'sợi')]
    return out



def export(pid, objs):
    """Áp modifier, gộp mọi phần thành một mesh (giữ riêng mặt ảnh Anh*), xuất .glb."""
    for o in objs:
        for md in list(o.modifiers):
            bpy.context.view_layer.objects.active = o
            bpy.ops.object.modifier_apply(modifier=md.name)
    keep = [o for o in objs if o.name.startswith('Anh')]
    rest = [o for o in objs if o not in keep]
    bpy.ops.object.select_all(action='DESELECT')
    for o in rest:
        o.select_set(True)
    bpy.context.view_layer.objects.active = rest[0]
    bpy.ops.object.join()
    rest[0].name = pid
    bpy.ops.object.select_all(action='DESELECT')
    for o in [rest[0]] + keep:
        o.select_set(True)
    path = os.path.join(OUT, pid + '.glb')
    bpy.ops.export_scene.gltf(filepath=path, use_selection=True, export_yup=True)
    print('xuất', path, os.path.getsize(path) // 1024, 'KB')


for pid, fn in (('khan_cam', khan_cam), ('gio_ngu', gio_ngu), ('bang_tuan', bang_tuan)):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    objs = fn()
    print(pid, tris(objs), 'tam giác')
    export(pid, objs)
