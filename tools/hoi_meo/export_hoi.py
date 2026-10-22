"""Nướng 13 động tác G10 (anims_hoi.py) lên một model game có rig 22 xương rồi xuất .glb có animation (NLA, 30 khung/giây).
- Cho game: nướng lên Bơ (assets/models/bo.glb) để dáng nghỉ trong JSON trùng bo_dong_tac.json; rồi
  python3 tools/dong_tac_bo/xuat_json.py-kiểu (xuat_json_hoi.py) ra assets/models/meo_hoi_dong_tac.json.
- Cho khung xem 3D trên trang: nướng lên Bà Mướp bản game.
Chạy: python3 export_hoi.py <model.glb> <out.glb>"""
import sys, os
import bpy
from mathutils import Matrix

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, '/home/user/meo-giao-banh-mi/tools/dong_tac_bo'); sys.path.insert(0, HERE)
SRC, OUT = sys.argv[1], sys.argv[2]
FPS = 30
bpy.ops.wm.read_factory_settings(use_empty=True)
import rig            # noqa: E402
import anims_hoi as AH  # noqa: E402

sc = bpy.context.scene
sc.render.fps = FPS
bpy.ops.import_scene.gltf(filepath=SRC)
arm = next(o for o in sc.objects if o.type == 'ARMATURE')
R = rig.Rig(arm)


def basis_of(pb):
    b = pb.bone
    if pb.parent:
        rest_rel = b.parent.matrix_local.inverted() @ b.matrix_local
        return (pb.parent.matrix @ rest_rel).inverted() @ pb.matrix
    return b.matrix_local.inverted() @ pb.matrix


bones = list(arm.pose.bones)
arm.animation_data_create()
for name, an in AH.ANIMS.items():
    keys = [(k, rig.full(dict(an.get('base', {}), **d))) for k, d in an['keys']]
    R.modes = {k: an.get('modes', {}).get(k, 'w') for k in rig.LEGS}
    n = int(round(an['dur'] * FPS))
    frames = []
    for f in range(n + 1):
        R.apply(rig.sample(keys, f / FPS))
        frames.append({pb.name: basis_of(pb).copy() for pb in bones})
    for k, (b1, b2, b3n, par) in rig.LEGS.items():
        for c in arm.pose.bones[b2].constraints: c.mute = True
        for c in arm.pose.bones[b3n].constraints: c.mute = True
    act = bpy.data.actions.new(name)
    arm.animation_data.action = act
    for f, mats in enumerate(frames):
        for pb in bones:
            loc, rot, scl = mats[pb.name].decompose()
            pb.location, pb.rotation_quaternion, pb.scale = loc, rot, scl
            for path in ('location', 'rotation_quaternion', 'scale'):
                pb.keyframe_insert(path, frame=f)
    tr = arm.animation_data.nla_tracks.new(); tr.name = name
    tr.strips.new(name, 0, act); tr.mute = True
    arm.animation_data.action = None
    for k, (b1, b2, b3n, par) in rig.LEGS.items():
        for c in arm.pose.bones[b2].constraints: c.mute = False
        for c in arm.pose.bones[b3n].constraints: c.mute = False
    print('anim', name, n + 1, 'khung', flush=True)

for tr in arm.animation_data.nla_tracks:
    tr.mute = False
for pb in bones:
    for c in list(pb.constraints):
        pb.constraints.remove(c)
    pb.location, pb.rotation_quaternion, pb.scale = (0, 0, 0), (1, 0, 0, 0), (1, 1, 1)
for e in R.tgt.values():
    bpy.data.objects.remove(e)
for o in sc.objects:
    o.select_set(o.type in ('MESH', 'ARMATURE'))
bpy.ops.export_scene.gltf(filepath=OUT, use_selection=True, export_vertex_color='ACTIVE', export_skins=True,
                          export_animations=True, export_animation_mode='NLA_TRACKS', export_force_sampling=True,
                          export_frame_step=1, export_optimize_animation_size=False)
print('exported', OUT)
