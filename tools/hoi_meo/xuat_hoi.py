"""Xuất bản game cho G10 bằng đúng công cụ tools/xuat_skin_game.py của repo (rig 22 xương, điểm gắn, giảm tam giác như Bơ).
- Bà Mướp: giong/bamuop_cai.glb + 3 phụ kiện mới (kinhlao, daykinh, khanchoang) vào phu_kien/.
- Bản nhẹ cho web (đám mèo trong hội): giong_nhe/<giống>_<giới>.glb, thân 3500 tam giác (giữ quanh mắt), tròng 1200, giữ nguyên xương và trọng số.
Chạy: python3 xuat_hoi.py <repo> <out_skin_dir> [bamuop|nhe|all]
(out_skin_dir thường là <repo>/assets/models/skin; skin.json được cập nhật thêm khoá mới, không đổi khoá cũ.)"""
import sys, os, json
HERE = os.path.dirname(os.path.abspath(__file__))
REPO, OUT = sys.argv[1], sys.argv[2]
WHAT = sys.argv[3] if len(sys.argv) > 3 else 'all'
sys.path.insert(0, HERE)
import hoi                                   # vá catcore (bụng xệ, lông bạc) + thêm giống 'bamuop'
import acc
acc.ACC.update({k: (lambda f: lambda: (f(), {}))(f) for k, f in hoi.NEW_ACC.items()})
sys.argv = ['xuat_skin_game.py', hoi.SK, OUT, 'none']
sys.path.insert(0, f'{REPO}/tools')
import xuat_skin_game as X                    # WHAT='none': chỉ nạp hàm, chưa xuất gì
X.SOCK.update(kinhlao='head', daykinh='neck', khanchoang='neck')
import bpy

if WHAT in ('bamuop', 'all'):
    X.export_breeds(['bamuop'], 'cai')
if WHAT in ('bamuop', 'pk', 'all'):
    X.export_acc(['kinhlao', 'daykinh', 'khanchoang'])

LIGHT = dict(Meo=3500)
if WHAT in ('nhe', 'all'):
    os.makedirs(f'{OUT}/giong_nhe', exist_ok=True)
    for cid, (name, bid, g, *_r) in hoi.CATS.items():
        src = f'{OUT}/giong/{bid}_{g}.glb'
        bpy.ops.wm.read_factory_settings(use_empty=True)
        bpy.ops.import_scene.gltf(filepath=src)
        cat = next(o for o in bpy.context.scene.objects if o.type == 'MESH')
        arm = next(o for o in bpy.context.scene.objects if o.type == 'ARMATURE')
        me = cat.data
        # tròng mắt có màu riêng (đồng tử nằm trong màu đỉnh): giữ dày quanh mắt bằng nhóm đỉnh như bản thường
        S = hoi.setup(cid); k = S['size']
        import numpy as np
        ec = S['eye']['c']
        eyes = [hoi.cc.head_world(np.array([s * ec[0], ec[1], ec[2]], np.float32)) * k for s in (-1, 1)]
        eb = [X.Vector((e[0], -e[2], e[1])) for e in eyes]
        gname = 'giu_mat_nhe'
        vg = cat.vertex_groups.new(name=gname)
        for vt in me.vertices:
            dd = min((cat.matrix_world @ vt.co - c).length for c in eb)
            if dd < .07:
                vg.add([vt.index], 1.0 - dd / .07, 'REPLACE')
        tris = len(me.polygons)
        md = cat.modifiers.new('Dec', 'DECIMATE'); md.ratio = min(1, (LIGHT['Meo'] + 2400) / tris)
        md.vertex_group = gname; md.vertex_group_factor = 1.2; md.invert_vertex_group = True
        X.select_only([cat]); bpy.ops.object.modifier_apply(modifier=md.name)
        cat.vertex_groups.remove(cat.vertex_groups[gname])
        X.export(f'{OUT}/giong_nhe/{bid}_{g}.glb', [cat, arm], skins=True)
        X.META.setdefault('giong_nhe', {})[f'{bid}_{g}'] = dict(tris=len(cat.data.polygons), src=f'giong/{bid}_{g}.glb')
        print('nhe', cid, bid, g, tris, '->', len(cat.data.polygons), flush=True)
    # phụ kiện của mèo hội, bản nhẹ: mỗi object tối đa 700 tam giác
    os.makedirs(f'{OUT}/phu_kien_nhe', exist_ok=True)
    for aid in sorted({a for c in hoi.CATS.values() for a in c[3]}):
        bpy.ops.wm.read_factory_settings(use_empty=True)
        bpy.ops.import_scene.gltf(filepath=f'{OUT}/phu_kien/{aid}.glb')
        objs = [o for o in bpy.context.scene.objects if o.type == 'MESH']
        for o in objs:
            X.decimate(o, 700)
        X.export(f'{OUT}/phu_kien_nhe/{aid}.glb', objs)
        X.META.setdefault('phu_kien_nhe', {})[aid] = dict(tris=sum(len(o.data.polygons) for o in objs))
        print('pk nhe', aid, X.META['phu_kien_nhe'][aid], flush=True)
json.dump(X.META, open(f'{OUT}/skin.json', 'w'), ensure_ascii=False, indent=1)
