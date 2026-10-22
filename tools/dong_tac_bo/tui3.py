"""Túi vải 3 ổ (model mới gói G2): ảnh 5 góc có lưới mét, ảnh so cỡ với Bơ, bản game ≤ 600 tam giác (màu đỉnh, một mesh).
Chạy: xvfb-run -a python3 tui3.py <out>"""
import sys
import json
import bpy
import bmesh
from mathutils import Vector

HERE = '/mnt/project-files/thiet-ke-man/goi-phac-thao/g2-bo'
sys.path.insert(0, HERE)
OUT = sys.argv[1]
bpy.ops.wm.read_factory_settings(use_empty=True)
import scene, props   # noqa: E402

cam, floor, wall = scene.setup(res=(640, 540), samples=48)
root, objs = props.tui_3o()
root.location.z = .125      # đáy túi chạm sàn
bpy.context.view_layer.update()
for v in ('q34', 'front', 'side', 'back', 'top'):
    scene.shoot(cam, wall, v, f'{OUT}/tui3_{v}.png', (0, 0, .1), .42)

# ---- bản game: mỗi bộ phận một ngân sách tam giác, gộp một mesh có màu đỉnh
BUDGET = {'Than': 150, 'Vien': 56, 'Quai': 80, 'Banh': 50, 'Khia': 6, 'Mieng': 40, 'Dem': 10}
deps = bpy.context.evaluated_depsgraph_get()
rows = {}
game_objs = []
for o in objs:
    me = bpy.data.meshes.new_from_object(o.evaluated_get(deps))
    me.transform(o.matrix_world)
    g = bpy.data.objects.new('G_' + o.name, me)
    bpy.context.scene.collection.objects.link(g)
    tris_hi = sum(len(p.vertices) - 2 for p in me.polygons)
    key = next(k for k in BUDGET if o.name.startswith(k))
    if tris_hi > BUDGET[key]:
        bpy.context.view_layer.objects.active = g
        for x in bpy.context.scene.objects:
            x.select_set(x is g)
        d = g.modifiers.new('Dec', 'DECIMATE'); d.ratio = BUDGET[key] / tris_hi
        bpy.ops.object.modifier_apply(modifier=d.name)
    tris = sum(len(p.vertices) - 2 for p in g.data.polygons)
    col = o.data.materials[0].node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value
    a = g.data.color_attributes.new('Color', 'BYTE_COLOR', 'CORNER')
    for c in a.data:
        c.color = tuple(col)
    rows.setdefault(key, [0, 0, 0]); rows[key][0] += tris_hi; rows[key][1] += tris; rows[key][2] += 1
    game_objs.append(g)
for o in bpy.context.scene.objects:
    o.select_set(o in game_objs)
bpy.context.view_layer.objects.active = game_objs[0]
bpy.ops.object.join()
gm = bpy.context.active_object
gm.name = 'Tui3o'
total = sum(len(p.vertices) - 2 for p in gm.data.polygons)
# gốc toạ độ ở điểm ngậm (đỉnh quai) như ổ bánh giao Thứ Hai
top = max(v.co.z for v in gm.data.vertices)
gm.data.transform(__import__('mathutils').Matrix.Translation((0, 0, -top)))
for o in bpy.context.scene.objects:
    o.select_set(o is gm)
bpy.ops.export_scene.gltf(filepath=f'{OUT}/tui_3o.glb', use_selection=True, export_vertex_color='ACTIVE', export_materials='NONE')
dims = [round(x, 3) for x in gm.dimensions]
json.dump({'parts': [(p[0], p[2], p[3], p[4]) for p in props.PARTS], 'tris': rows, 'total': total, 'dims': dims},
          open(f'{OUT}/tui3.json', 'w'), ensure_ascii=False, indent=1)
print('tris game', total, rows, dims)
