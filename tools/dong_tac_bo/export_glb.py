"""Xuất Bơ bản game (15k tam giác, rig 22 xương) kèm các animation trong anims.py (18 G2 + 5 phim C1) vào một .glb cho khung xem 3D trên trang phác thảo
(và để luồng code đọc số liệu). Mỗi animation lấy mẫu 30 khung/giây từ anims.py, IK chân được nướng thành góc xương.
Chạy: xvfb-run -a python3 export_glb.py <out.glb>"""
import sys
import math
import bpy
from mathutils import Vector, Matrix

HERE = '/mnt/project-files/thiet-ke-man/goi-phac-thao/g2-bo'
sys.path.insert(0, HERE)
sys.path.insert(0, __file__.rsplit('/', 1)[0])  # anims.py, rig.py, props.py trong repo (động tác mới thêm ở đây)
OUT = sys.argv[1]
FPS = 30
bpy.ops.wm.open_mainfile(filepath=f'{HERE}/bo_game.blend')
import rig, props, anims   # noqa: E402

sc = bpy.context.scene
sc.render.fps = FPS
arm = bpy.data.objects['BoRig']
R = rig.Rig(arm)
MOUTH = Vector((0, -.30, .368))

bag = props.tui_cheo()
for o in bag:
    props.parent_bone(o, arm, 'hips')
bpy.ops.import_scene.gltf(filepath=f'{HERE}/tui3/tui_3o.glb')
b3 = [o for o in bpy.context.selected_objects if o.type == 'MESH'][0]
b3.name = 'Tui3o'
piv = bpy.data.objects.new('Tui3oPivot', None)
sc.collection.objects.link(piv)
piv.location = MOUTH
bpy.context.view_layer.update()
b3.parent = piv
b3.matrix_parent_inverse = Matrix()
b3.location = (0, 0, 0)
b3.rotation_mode = 'XYZ'
b3.rotation_euler = (0, 0, 0)
props.parent_bone(piv, arm, 'head')
medal = props.huy_chuong()
for o in medal:
    props.parent_bone(o, arm, 'chest')
ctx = props.canh()


def merge_base(an, d):
    o = dict(an.get('base', {}))
    o.update(d)
    return o


def basis_of(pb):
    """Ma trận cơ sở (local) của xương sau khi đã tính ràng buộc IK, để ghi keyframe."""
    b = pb.bone
    if pb.parent:
        rest_rel = b.parent.matrix_local.inverted() @ b.matrix_local
        return (pb.parent.matrix @ rest_rel).inverted() @ pb.matrix
    return b.matrix_local.inverted() @ pb.matrix


bones = list(arm.pose.bones)
import os
ONLY = os.environ.get('ONLY', '')   # vd ONLY=cho_khen,dui_dau: chỉ xuất mấy động tác này (rồi xuat_json.py --gop)
for name, an in [(k, a) for k, a in anims.ANIMS.items() if not ONLY or k in ONLY.split(',')]:
    keys = [(k, rig.full(merge_base(an, d))) for k, d in an['keys']]
    R.modes = {k: an.get('modes', {}).get(k, 'w') for k in rig.LEGS}
    n = int(round(an['dur'] * FPS))
    frames = []
    for f in range(n + 1):
        p = rig.sample(keys, f / FPS)
        R.apply(p)
        mats = {pb.name: basis_of(pb).copy() for pb in bones}
        hold = p.get('bag3', (0, 1))[1] > .5 if an.get('bag3') else False
        sw = math.radians(p.get('bag3', (0, 0))[0])
        pos = piv.matrix_world.translation.copy()
        pw = Matrix.Translation(pos) @ Matrix.Rotation(sw, 4, 'X') @ Matrix.Scale(1 if hold else 1e-4, 4)
        frames.append((mats, pw, p.get('medal', (0,))[0] > .5))
    # ghi keyframe: tắt ràng buộc để ma trận cơ sở là tất cả
    for k, (b1, b2, b3n, par) in rig.LEGS.items():
        for c in arm.pose.bones[b2].constraints: c.mute = True
        for c in arm.pose.bones[b3n].constraints: c.mute = True
    arm.animation_data_create()
    act = bpy.data.actions.new(name)
    arm.animation_data.action = act
    piv.animation_data_create()
    pact = bpy.data.actions.new(name + '_tui3')
    piv.animation_data.action = pact
    macts = []
    for o in medal:
        o.animation_data_create()
        a = bpy.data.actions.new(name + '_' + o.name)
        o.animation_data.action = a
        macts.append(a)
    for f, (mats, pw, med) in enumerate(frames):
        for pb in bones:
            loc, rot, scl = mats[pb.name].decompose()
            pb.location, pb.rotation_quaternion, pb.scale = loc, rot, scl
            for path in ('location', 'rotation_quaternion', 'scale'):
                pb.keyframe_insert(path, frame=f)
        bpy.context.view_layer.update()
        piv.matrix_world = pw
        for path in ('location', 'rotation_euler', 'scale'):
            piv.keyframe_insert(path, frame=f)
        for o in medal:
            o.scale = (1, 1, 1) if med else (1e-4,) * 3
            o.keyframe_insert('scale', frame=f)
    for o, a in [(arm, act), (piv, pact)] + list(zip(medal, macts)):
        tr = o.animation_data.nla_tracks.new()
        tr.name = name
        tr.strips.new(name, 0, a)
        tr.mute = True   # tắt khi nướng động tác sau, không thì NLA ghi đè khung đầu của động tác sau
        o.animation_data.action = None
    for k, (b1, b2, b3n, par) in rig.LEGS.items():
        for c in arm.pose.bones[b2].constraints: c.mute = False
        for c in arm.pose.bones[b3n].constraints: c.mute = False
    print('anim', name, n + 1, 'khung')

for o in sc.objects:
    if o.animation_data:
        for tr in o.animation_data.nla_tracks:
            tr.mute = False
# về dáng nghỉ, bỏ ràng buộc và đích IK trước khi xuất
for pb in bones:
    for c in list(pb.constraints):
        pb.constraints.remove(c)
    pb.location, pb.rotation_quaternion, pb.scale = (0, 0, 0), (1, 0, 0, 0), (1, 1, 1)
for e in R.tgt.values():
    bpy.data.objects.remove(e)
piv.matrix_world = Matrix.Translation(piv.matrix_world.translation)
for o in sc.objects:
    o.select_set(o.type in ('MESH', 'ARMATURE', 'EMPTY'))
bpy.ops.export_scene.gltf(filepath=OUT, use_selection=True, export_vertex_color='ACTIVE', export_skins=True,
                          export_animations=True, export_animation_mode='NLA_TRACKS', export_force_sampling=True,
                          export_frame_step=1, export_optimize_animation_size=False)
print('exported', OUT)
