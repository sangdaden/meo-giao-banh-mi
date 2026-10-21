"""Chuyển model phác thảo Bơ kiểu D (chung2.glb) thành bản tạm cho game.

Chạy:  python3 tools/bo_game.py <chung2.glb> assets/models/bo.glb
(Cần: pip install bpy)

Việc script làm:
1. Giảm số tam giác từ ~115k xuống ~6k cho nhẹ (style guide: Bơ 4–6k), giữ chi tiết quanh mắt.
2. Dồn màu lông, khăn, mắt vào một lớp màu đỉnh (COLOR_0) để Godot đọc được.
3. Gắn bộ xương 16 xương: root, spine, head, 4 chân, 4 đốt đuôi, 2 tai, 2 mắt, khăn.
   Trọng số (weight) tính theo vị trí từng đỉnh, không cần vẽ tay.
4. Xuất .glb có xương (chưa có animation; game tự xoay xương bằng code).

Đây là bản tạm: tuần 2 sẽ dựng tay model chính thức 22 xương theo style guide.
"""
import sys
import bpy
from mathutils import Vector

src, dst = sys.argv[-2], sys.argv[-1]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=src)

meshes = [o for o in bpy.context.scene.objects if o.type == 'MESH']
for o in meshes:
    bpy.context.view_layer.objects.active = o
    for oo in meshes:
        oo.select_set(oo is o)
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)

# Tâm hai mắt (cầu tròng mắt tên 'Mat...'): vùng quanh mắt được giữ nhiều tam giác hơn,
# nếu không mí mắt bị bào thành hình bát giác và tròng mất màu hổ phách (trông như đeo kính)
eye_centers = []
for o in meshes:
    if o.name.startswith('Mat'):
        vs = [v.co for v in o.data.vertices]
        eye_centers.append(sum(vs, Vector()) / len(vs))


def target_tris(name):
    if name.startswith('Bo_Than'):
        return 9000
    if name.startswith('Bo_Khan'):
        return 700
    if name.startswith('Mat'):
        return 2400    # tròng mắt: màu đồng tử khe dọc nằm ở màu đỉnh, 350 tam giác thì mất hẳn đồng tử (mắt nâu đục, trông buồn)
    return 40          # đốm sáng trong mắt


for o in meshes:
    bpy.context.view_layer.objects.active = o
    for oo in meshes:
        oo.select_set(oo is o)
    tris = sum(len(p.vertices) - 2 for p in o.data.polygons)
    target = target_tris(o.name)
    if tris > target:
        md = o.modifiers.new('Dec', 'DECIMATE')
        md.ratio = target / tris
        if o.name.startswith('Bo_Than'):
            keep = o.vertex_groups.new(name='giu_mat')
            for v in o.data.vertices:
                d = min((v.co - c).length for c in eye_centers)
                if d < .08:
                    keep.add([v.index], 1.0 - d / .08, 'REPLACE')
            md.vertex_group = 'giu_mat'
            md.vertex_group_factor = 1.5
            md.invert_vertex_group = True  # trọng số 0 = giữ nguyên, nên đảo để vùng mắt được giữ
        bpy.ops.object.modifier_apply(modifier=md.name)

# Màu: lông và mắt đã có màu đỉnh tên 'Color'. Khăn và đốm sáng trong mắt chưa có,
# nên tô màu đỉnh bằng màu vật liệu để khi gộp mesh chỉ còn một lớp màu đỉnh duy nhất.
for o in meshes:
    if o.data.color_attributes.get('Color'):
        continue
    m = o.data.materials[0]
    bsdf = m.node_tree.nodes.get('Principled BSDF')
    col = (1, 1, 1, 1) if m.name.startswith('Sang') else tuple(bsdf.inputs['Base Color'].default_value)
    attr = o.data.color_attributes.new('Color', 'BYTE_COLOR', 'CORNER')
    for d in attr.data:
        d.color = col

# Gộp thành một mesh (nhiều vật liệu): một lần vẽ cho mỗi vật liệu
for o in meshes:
    o.select_set(True)
bpy.context.view_layer.objects.active = meshes[0]
bpy.ops.object.join()
cat = bpy.context.active_object
cat.name = 'Bo'
cat.data.color_attributes.active_color = cat.data.color_attributes['Color']
print('tris', sum(len(p.vertices) - 2 for p in cat.data.polygons))

def ramp(v, a, b):
    """0 khi v ở a, 1 khi v ở b, mượt ở giữa."""
    t = max(0.0, min(1.0, (v - a) / (b - a)))
    return t * t * (3 - 2 * t)


# Toạ độ Blender: X phải, -Y là phía trước mặt mèo, Z lên trên.
BONES = {
    # tên: (đầu, đuôi, cha)
    'root':   ((0, 0, 0), (0, 0, .08), None),
    'spine':  ((0, .16, .25), (0, -.08, .29), 'root'),
    'head':   ((0, -.1, .34), (0, -.17, .5), 'spine'),
    'leg_FL': ((-.056, -.1, .27), (-.056, -.1, .01), 'spine'),
    'leg_FR': ((.056, -.1, .27), (.056, -.1, .01), 'spine'),
    'leg_BL': ((-.064, .15, .23), (-.064, .15, .01), 'spine'),
    'leg_BR': ((.064, .15, .23), (.064, .15, .01), 'spine'),
    # Đuôi 4 đốt (~7,5 cm mỗi đốt, tổng ~0,30 m) theo đường cong của đuôi phác thảo:
    # mọc ở mông, rủ xuống ra sau, rồi cong lên ở chóp
    'tail_1': ((0, .2, .27), (0, .28, .25), 'spine'),
    'tail_2': ((0, .28, .25), (0, .35, .28), 'tail_1'),
    'tail_3': ((0, .35, .28), (.01, .38, .35), 'tail_2'),
    'tail_4': ((.01, .38, .35), (.02, .375, .42), 'tail_3'),
}
TAIL = [n for n in BONES if n.startswith('tail')]

# Vật liệu của từng đỉnh (sau khi gộp mesh), để tìm mắt, khăn
mat_of = {}
for poly in cat.data.polygons:
    name = cat.data.materials[poly.material_index].name
    for vi in poly.vertices:
        mat_of[vi] = name


def center(pts):
    return sum(pts, Vector()) / len(pts)


# Mắt: một xương cho mỗi mắt (tròng + đốm sáng), dựng đứng để co trục Y là chớp mắt
eye_pts = {'eye_L': [], 'eye_R': []}
for v in cat.data.vertices:
    m = mat_of.get(v.index, '')
    if m.startswith('Mat') or m.startswith('Sang'):
        eye_pts['eye_L' if v.co.x < .035 else 'eye_R'].append(v.co.copy())
for n, pts in eye_pts.items():
    c = center(pts)
    BONES[n] = (tuple(c), tuple(c + Vector((0, 0, .03))), 'head')

# Tai: hai chóp nhọn trên đỉnh đầu; xương mọc từ chân tai lên chóp tai
ear_pts = [v.co.copy() for v in cat.data.vertices if v.co.z > .53 and v.co.y < -.1]
mid_x = center(ear_pts).x
for n, side in (('ear_L', -1), ('ear_R', 1)):
    pts = [p for p in ear_pts if (p.x - mid_x) * side > 0]
    c = center(pts)
    tip = max(pts, key=lambda p: p.z)
    BONES[n] = ((c.x, c.y, .5), tuple(tip), 'head')

# Khăn: phần nút và hai mép rủ trước ngực đung đưa theo quán tính
knot = [v.co.copy() for v in cat.data.vertices if mat_of.get(v.index) == 'Khan' and v.co.z < .32]
kc = center(knot)
BONES['scarf'] = ((kc.x, kc.y, .32), (kc.x, kc.y - .01, min(p.z for p in knot)), 'spine')
print('eyes', [tuple(round(c, 3) for c in BONES[n][0]) for n in ('eye_L', 'eye_R')],
      'ears', [tuple(round(c, 3) for c in BONES[n][1]) for n in ('ear_L', 'ear_R')],
      'scarf', tuple(round(c, 3) for c in BONES['scarf'][0]))

arm_data = bpy.data.armatures.new('BoRig')
arm = bpy.data.objects.new('BoRig', arm_data)
bpy.context.scene.collection.objects.link(arm)
bpy.context.view_layer.objects.active = arm
bpy.ops.object.mode_set(mode='EDIT')
for name, (h, t, parent) in BONES.items():
    b = arm_data.edit_bones.new(name)
    b.head, b.tail = Vector(h), Vector(t)
    b.roll = 0
    if parent:
        b.parent = arm_data.edit_bones[parent]
bpy.ops.object.mode_set(mode='OBJECT')


groups = {n: cat.vertex_groups.new(name=n) for n in BONES if n != 'root'}
for v in cat.data.vertices:
    x, y, z = v.co
    w = {}
    # Chân: cột thẳng đứng dưới thân
    for n, (lx, ly, top) in {'leg_FL': (-.056, -.1, .2), 'leg_FR': (.056, -.1, .2),
                             'leg_BL': (-.064, .15, .17), 'leg_BR': (.064, .15, .17)}.items():
        # Bàn chân rộng và dài hơn ống chân: nới hộp ở sát đất để ngón chân đi theo khi nhấc chân
        low = z < .06
        if abs(x - lx) < (.06 if low else .05) and abs(y - ly) < (.11 if low else .075) and z < top + .04:
            w[n] = ramp(z, top + .04, top - .06)
    # Đầu: phía trước và cao hơn cổ
    if y < -.05 and z > .3:
        w['head'] = ramp(z, .31, .37) * ramp(y, -.05, -.11)
    m = mat_of.get(v.index, '')
    # Mắt: theo trọn xương mắt
    if m.startswith('Mat') or m.startswith('Sang'):
        w = {'eye_L' if x < .035 else 'eye_R': 1.0}
    # Tai: phần trên chân tai theo xương tai
    elif z > .5 and y < -.1 and abs(x - mid_x) > .035:
        ear = 'ear_L' if x < mid_x else 'ear_R'
        k = ramp(z, .5, .545)
        w = {ear: k, 'head': 1.0 - k}
    # Khăn: phần dưới cổ (nút, mép rủ) theo xương khăn
    elif m == 'Khan' and z < .32:
        k = ramp(z, .32, .28)
        w = {n: val * (1 - k) for n, val in w.items()}
        w['scarf'] = k
    # Đuôi: mỗi đỉnh chia trọng số cho đốt gần nhất và đốt kề nó, để chỗ gập mềm
    if y > .17 and z > .18:
        p = Vector((x, y, z))
        d = []
        for n in TAIL:
            h, t = Vector(BONES[n][0]), Vector(BONES[n][1])
            seg = t - h
            k = max(0.0, min(1.0, (p - h).dot(seg) / seg.length_squared))
            d.append(((p - (h + seg * k)).length, n, k))
        d.sort()
        if d[0][0] < (.08 if d[0][1] in ('tail_1', 'tail_2') else .09):
            inv = [1.0 / (dist + .004) ** 3 for dist, _, _ in d[:2]]
            base = ramp(y, .17, .21) if d[0][1] == 'tail_1' else 1.0
            for (dist, n, _), iv in zip(d[:2], inv):
                w[n] = w.get(n, 0) + base * iv / sum(inv)
    rest = max(0.0, 1.0 - sum(w.values()))
    w['spine'] = w.get('spine', 0) + rest
    for n, val in w.items():
        if val > 0.001:
            groups[n].add([v.index], val, 'REPLACE')

cat.parent = arm
md = cat.modifiers.new('Armature', 'ARMATURE')
md.object = arm

for o in bpy.context.scene.objects:
    o.select_set(o in (cat, arm))
bpy.ops.export_scene.gltf(filepath=dst, use_selection=True, export_vertex_color='ACTIVE',
                          export_skins=True, export_animations=False)
print('exported', dst)
