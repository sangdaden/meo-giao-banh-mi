"""Đo mặt mái thật của các mẫu nhà phố (assets/models/pho) cho đường sân thượng Thứ Tư (scripts/san_thuong.gd ROOF_PROFILE).
Bắn tia thẳng xuống ở 3 dải ngang (25/50/75 % bề ngang), 16 điểm cách mặt tiền 0..7,5 m. Cần bpy.
Dùng: python3 tools/do_mai_nha.py assets/models/pho  (in ra bảng, ghi /tmp/do_mai_nha.json)"""
import bpy, sys, json
from mathutils.bvhtree import BVHTree
from mathutils import Vector
DIR = sys.argv[1]
models = ["nha_A","nha_B","nha_C","nha_D","nha_E","nha_F","nha_G","nha_H","nha_I","nha_K","lo_banh"]
res = {}
for m in models:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=f"{DIR}/{m}.glb")
    dg = bpy.context.evaluated_depsgraph_get()
    verts, polys = [], []
    for o in bpy.context.scene.objects:
        if o.type != 'MESH': continue
        me = o.evaluated_get(dg).to_mesh(); base = len(verts)
        verts += [o.matrix_world @ v.co for v in me.vertices]
        polys += [[base + i for i in p.vertices] for p in me.polygons]
    bvh = BVHTree.FromPolygons(verts, polys)
    xs = [v.x for v in verts]; x0, x1 = min(xs), max(xs)
    rows = []
    for xf in (0.25, 0.5, 0.75):
        x = x0 + (x1 - x0) * xf; row = []
        for zi in range(16):
            # Godot z = -Blender y; Godot local z = -0.5*zi -> Blender y = 0.5*zi
            hit = bvh.ray_cast(Vector((x, 0.5 * zi, 60)), Vector((0, 0, -1)))
            row.append(round(hit[0].z, 2) if hit[0] else -1)
        rows.append(row)
    res[m] = dict(x=[round(x0,2), round(x1,2)], rows=rows)
    print(m, res[m]["x"]); [print("   ", r) for r in rows]
json.dump(res, open('/tmp/do_mai_nha.json', 'w'))
