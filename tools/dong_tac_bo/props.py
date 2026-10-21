"""Đồ đi kèm động tác G2, dựng bằng Blender (phong cách D: khối mềm, bo tròn, vải mờ).
- tui_cheo: túi đeo chéo đã duyệt ở trang Thứ Hai (dựng lại theo số đo bag_sdf), gắn xương hips.
- tui_3o: túi vải nhỏ có quai đựng 3 ổ bánh mì nhỏ (Thứ Sáu, chuyền túi Chủ Nhật) — model MỚI, có bảng bộ phận.
- huy_chuong: huy chương tạm để dựng dáng (mẫu chính thức thuộc gói G11).
- cảnh: mép tường, ống nước, hai tường khe, ván gỗ — khối tham chiếu, không phải model của gói này.
Toạ độ Blender: X phải, -Y trước, Z lên (mét)."""
import math
import random
import bpy
import bmesh
from mathutils import Vector, Matrix
from scene import mat, lin

PARTS = []   # (tên, đối tượng, mô tả, màu, vật liệu) của túi 3 ổ để in bảng bộ phận


def _obj(name, me, m):
    o = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(o)
    if m:
        o.data.materials.append(m)
    return o


def rbox(name, size, loc, m, bevel=.01, seg=3, sub=0, rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc, rotation=rot)
    o = bpy.context.active_object
    o.name = name
    o.scale = size
    bpy.ops.object.transform_apply(scale=True)
    b = o.modifiers.new('Bo', 'BEVEL'); b.width = bevel; b.segments = seg
    if sub:
        s = o.modifiers.new('Min', 'SUBSURF'); s.levels = sub; s.render_levels = sub
    o.data.materials.append(m)
    bpy.ops.object.shade_smooth()
    return o


def capsule(name, length, r, loc, rot, m, seg=16):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=seg, ring_count=seg // 2, radius=1, location=loc, rotation=rot)
    o = bpy.context.active_object
    o.name = name
    o.scale = (r, r, length / 2)
    bpy.ops.object.transform_apply(scale=True)
    o.data.materials.append(m)
    bpy.ops.object.shade_smooth()
    return o


def torus(name, R, r, loc, rot, m, major=48, minor=10, arc=None):
    bpy.ops.mesh.primitive_torus_add(major_radius=R, minor_radius=r, major_segments=major, minor_segments=minor,
                                     location=loc, rotation=rot)
    o = bpy.context.active_object
    o.name = name
    if arc is not None:
        # giữ cung phía trên (z cục bộ... trục Y của vòng): bỏ các đỉnh có y < arc
        bm = bmesh.new(); bm.from_mesh(o.data)
        bmesh.ops.delete(bm, geom=[v for v in bm.verts if v.co.y < arc], context='VERTS')
        bm.to_mesh(o.data); bm.free()
    o.data.materials.append(m)
    bpy.ops.object.shade_smooth()
    return o


# ------------------------------------------------------------------ túi đeo chéo (Thứ Hai, đã duyệt)
def tui_cheo():
    tm = mat('Tui', '#2E7C80', rough=.9, sheen=1)
    tm2 = mat('TuiNap', '#25686B', rough=.9, sheen=1)
    gold = mat('Khoa', '#E8C15A', rough=.35, metal=.6)
    c = Vector((.128, 0, .24))
    out = [rbox('TuiThan', (.048, .124, .092), c, tm, .012),
           rbox('TuiNap', (.052, .13, .04), c + Vector((.003, 0, .03)), tm2, .009),
           rbox('TuiKhoa', (.008, .024, .02), c + Vector((.03, 0, .012)), gold, .003)]
    # quai: vòng dẹt ôm thân, nghiêng theo mặt phẳng n của bag_sdf
    n = Vector((.55, -.8, -.25)).normalized()
    q = Vector((0, 0, 1)).rotation_difference(n)
    o = torus('TuiQuai', .118, .007, (0, -.04, .28), q.to_euler(), tm2, major=64, minor=8)
    o.scale = (1.0, 1.08, .7)
    out.append(o)
    return out


# ------------------------------------------------------------------ túi vải 3 ổ (MỚI)
def tui_3o():
    PARTS.clear()
    linen = mat('Vai', '#E9DCC0', rough=.95, sheen=1)
    hem = mat('Vien', '#C8412F', rough=.9, sheen=1)
    rope = mat('Quai3', '#8A5A3A', rough=.85, sheen=.6)
    crust = mat('VoBanh', '#D3913F', rough=.55)
    score = mat('KhiaBanh', '#F2D29B', rough=.7)
    patch = mat('Mieng', '#E8913A', rough=.9, sheen=1)
    paw = mat('ChanMeo', '#6B3A1E', rough=.9)
    W, D, H = .20, .10, .12       # rộng, dày, cao thân túi (Thiết kế màn đề xuất ~0,24×0,12×0,14; thu nhỏ để không che ngực Bơ)
    top = 0.0                     # miệng túi ở z = 0, túi treo bên dưới
    body = rbox('Than', (W, D, H), (0, 0, top - H / 2), linen, .035, 4, sub=1)
    # thân túi phình nhẹ ở đáy như vải chứa đồ: kéo các đỉnh dưới ra ngoài
    for v in body.data.vertices:
        k = max(0.0, (-v.co.z - .02) / H)
        v.co.x *= 1 + .06 * k
        v.co.y *= 1 + .14 * k
        if v.co.z > -.03:                    # miệng túi chụm lại như túi vải rút
            v.co.x *= .92
            v.co.y *= .85
    PARTS.append(('Thân túi', body, f'hộp vải bo tròn {W*100:.0f}×{D*100:.0f}×{H*100:.0f} cm, đáy phình', '#E9DCC0', 'vải lanh mờ'))
    rim = rbox('Vien', (W * .93, D * .88, .022), (0, 0, top - .012), hem, .008, 2)
    PARTS.append(('Viền miệng túi', rim, 'dải vải đỏ cao 2,2 cm ôm miệng túi, cùng màu khăn Bơ', '#C8412F', 'vải'))
    # quai: cung tròn trên miệng túi, Bơ ngậm ở đỉnh quai
    h = torus('Quai', .065, .008, (0, 0, top - .01), (math.pi / 2, 0, 0), rope, major=40, minor=8, arc=-.005)
    PARTS.append(('Quai', h, 'dây thừng vải tròn Ø1,6 cm, cung cao 6,5 cm; điểm ngậm ở đỉnh', '#8A5A3A', 'sợi bông'))
    # 3 ổ bánh mì nhỏ thò đầu ra, xoè nhẹ
    for i, (x, tilt, yaw) in enumerate(((-.055, -.38, .15), (0, .06, 0), (.055, .36, -.15))):
        b = capsule(f'Banh{i+1}', .16, .024, (x, .012 * (i - 1), top - .005), (0, tilt, yaw), crust)
        for v in b.data.vertices:            # ổ dẹt dưới, phồng trên như bánh mì Việt
            if v.co.y > 0:
                v.co.y *= .8
        PARTS.append((f'Ổ bánh {i+1}', b, 'ổ bánh mì nhỏ dài 16 cm, Ø4,8 cm, thò 7 cm khỏi miệng túi, xoè hình quạt', '#D3913F', 'vỏ giòn bóng nhẹ'))
        for j in range(3):                   # 3 vết khía trên mặt ổ
            z = -.045 + j * .045
            p = Matrix.Rotation(yaw, 4, 'Z') @ Matrix.Rotation(tilt, 4, 'Y') @ Vector((0, -.0175, z, 1))
            s = capsule(f'Khia{i+1}{j}', .028, .0055, (x + p.x, .012 * (i - 1) + p.y, top - .005 + p.z), (0, tilt, yaw + .5), score, seg=8)
            if j == 0:
                PARTS.append((f'Khía ổ {i+1} (×3)', s, 'vết khía xẻ vỏ dài 3 cm', '#F2D29B', 'ruột bánh'))
    pt = rbox('Mieng', (.06, .006, .06), (0, -D / 2 - .003, top - .068), patch, .018, 3)
    PARTS.append(('Miếng vá in chân mèo', pt, 'miếng vải cam 6×6 cm may ở mặt trước', '#E8913A', 'vải nỉ'))
    for j, (dx, dz, r) in enumerate(((0, -.008, .014), (-.017, .012, .006), (0, .019, .006), (.017, .012, .006))):
        bpy.ops.mesh.primitive_cylinder_add(vertices=16, radius=r, depth=.003, location=(dx * .85, -D / 2 - .0065, top - .068 + dz * .85),
                                            rotation=(math.pi / 2, 0, 0))
        o = bpy.context.active_object; o.name = f'Dem{j}'; o.data.materials.append(paw)
        if j == 0:
            PARTS.append(('Dấu chân (đệm ×4)', o, '1 đệm lớn Ø2,8 cm + 3 ngón Ø1,2 cm', '#6B3A1E', 'chỉ thêu'))
    objs = [o for o in bpy.context.scene.objects if o.type == 'MESH' and (o.name.startswith(('Than', 'Vien', 'Quai', 'Banh', 'Khia', 'Mieng', 'Dem')))]
    root = bpy.data.objects.new('Tui3o', None)
    bpy.context.scene.collection.objects.link(root)
    for o in objs:
        o.parent = root
    return root, objs


# ------------------------------------------------------------------ huy chương tạm (mẫu chính thức: G11)
def huy_chuong():
    gold = mat('Vang', '#E8B83A', rough=.3, metal=.8)
    rib = mat('Ruy', '#2D6FB5', rough=.9, sheen=1)
    ring = torus('HCDay', .095, .009, (0, -.1, .3), (math.radians(-55), 0, 0), rib, major=48, minor=6)
    ring.scale = (1.05, 1.0, .8)
    bpy.ops.mesh.primitive_cylinder_add(vertices=32, radius=.042, depth=.01, location=(0, -.215, .215), rotation=(math.radians(75), 0, 0))
    d = bpy.context.active_object; d.name = 'HCDia'; d.data.materials.append(gold)
    b = d.modifiers.new('Bo', 'BEVEL'); b.width = .003; b.segments = 2
    return [ring, d]


def giot_nuoc(center, n=40, seed=3):
    w = mat('Nuoc', '#BFE6F5', rough=.05)
    w.node_tree.nodes['Principled BSDF'].inputs['Transmission Weight'].default_value = .6
    random.seed(seed)
    out = []
    for i in range(n):
        a = random.uniform(0, 2 * math.pi); z = random.uniform(-.1, .2); r = random.uniform(.16, .32)
        p = Vector(center) + Vector((math.cos(a) * r, math.sin(a) * r * 1.3, z))
        bpy.ops.mesh.primitive_uv_sphere_add(segments=10, ring_count=6, radius=random.uniform(.008, .016), location=p)
        o = bpy.context.active_object; o.name = f'Giot{i}'; o.data.materials.append(w)
        o.scale = (1, 1, 1.6)
        out.append(o)
    return out


# ------------------------------------------------------------------ khối cảnh tham chiếu
def canh():
    be = mat('BeTong', '#CFC6B6', rough=.95)
    go = mat('Go', '#9A6A3E', rough=.8)
    ong = mat('Ong', '#7FA3A8', rough=.5)
    C = {}
    # Mép tường Thứ Năm: mặt tường ở 0,27 m trước gốc mèo, mặt mép cao 0,5 m (như _try_grab)
    C['ledge'] = [rbox('Mep', (.9, .4, 1.3), (0, -.27 - .2, -.15), be, .004, 1)]
    # Ống nước Ø10 cm cách gốc 0,24 m, áp tường
    bpy.ops.mesh.primitive_cylinder_add(vertices=24, radius=.05, depth=2.6, location=(0, -.24, .5))
    o = bpy.context.active_object; o.name = 'OngNuoc'; o.data.materials.append(ong)
    C['pipe'] = [o, rbox('TuongOng', (.9, .2, 2.6), (0, -.24 - .05 - .1, .5), be, .004, 1)]
    for z in (.45, 1.05):
        C['pipe'].append(torus(f'Dai{z}', .056, .006, (0, -.24, z), (0, 0, 0), ong, major=24, minor=6))
    # Khe hai nhà 1,2 m: chỉ dựng bức Bơ đạp vào (sau lưng)
    C['walls'] = [rbox('TuongKhe', (1.4, .2, 1.6), (0, .32 + .1, .8), be, .004, 1)]
    # Ván gỗ rộng 0,25 m dày 3 cm bắc qua khe giữa hai mái (mặt ván ở z = 0, mái dưới thấp hơn 0,6 m)
    C['plank'] = [rbox('Van', (.25, 2.2, .03), (0, 0, -.015), go, .004, 1),
                  rbox('Mai1', (1.4, .5, .6), (0, 1.3, -.3), be, .004, 1),
                  rbox('Mai2', (1.4, .5, .6), (0, -1.3, -.3), be, .004, 1)]
    return C


def parent_bone(o, arm, bone):
    bpy.context.view_layer.update()
    mw = o.matrix_world.copy()
    o.parent = arm
    o.parent_type = 'BONE'
    o.parent_bone = bone
    o.matrix_world = mw
