"""Chuyển model phác thảo Bơ kiểu D (chung2.glb) thành bản tạm cho game.

Chạy:  python3 tools/bo_game.py <chung2.glb> assets/models/bo.glb
(Cần: pip install bpy)

Việc script làm:
1. Giảm số tam giác từ ~115k xuống ~6k cho nhẹ (style guide: Bơ 4–6k).
2. Dồn màu lông, khăn, mắt vào một lớp màu đỉnh (COLOR_0) để Godot đọc được.
3. Gắn bộ xương đơn giản 9 xương: root, spine, head, 4 chân, 2 đốt đuôi.
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
    tris = sum(len(p.vertices) - 2 for p in o.data.polygons)
    target = 4200 if o.name.startswith('Bo_Than') else (900 if o.name.startswith('Bo_Khan') else 120)
    if tris > target:
        md = o.modifiers.new('Dec', 'DECIMATE')
        md.ratio = target / tris
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
    'tail_1': ((0, .2, .3), (0, .27, .42), 'spine'),
    'tail_2': ((0, .27, .42), (0, .3, .62), 'tail_1'),
}
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


def ramp(v, a, b):
    """0 khi v ở a, 1 khi v ở b, mượt ở giữa."""
    t = max(0.0, min(1.0, (v - a) / (b - a)))
    return t * t * (3 - 2 * t)


groups = {n: cat.vertex_groups.new(name=n) for n in BONES if n != 'root'}
for v in cat.data.vertices:
    x, y, z = v.co
    w = {}
    # Chân: cột thẳng đứng dưới thân
    for n, (lx, ly, top) in {'leg_FL': (-.056, -.1, .2), 'leg_FR': (.056, -.1, .2),
                             'leg_BL': (-.064, .15, .17), 'leg_BR': (.064, .15, .17)}.items():
        if abs(x - lx) < .05 and abs(y - ly) < .075 and z < top + .04:
            w[n] = ramp(z, top + .04, top - .06)
    # Đầu: phía trước và cao hơn cổ
    if y < -.05 and z > .3:
        w['head'] = ramp(z, .31, .37) * ramp(y, -.05, -.11)
    # Đuôi: phía sau mông
    if y > .17 and z > .24:
        t = ramp(y, .17, .23)
        hi = ramp(z, .38, .48)
        w['tail_1'] = t * (1 - hi)
        w['tail_2'] = t * hi
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
