"""Render phác thảo động tác G2: dải khung hình khoá + 4 góc của khung chính, trên Bơ chuẩn (chung2, 111k tam giác) gắn rig 22 xương.
Chạy: xvfb-run -a python3 make.py <out> [tên,tên|all] [--draft]"""
import sys
import math
import bpy
from mathutils import Vector, Matrix

HERE = '/mnt/project-files/thiet-ke-man/goi-phac-thao/g2-bo'
sys.path.insert(0, HERE)
OUT = sys.argv[1]
WANT = sys.argv[2] if len(sys.argv) > 2 and not sys.argv[2].startswith('--') else 'all'
DRAFT = '--draft' in sys.argv
ONLY_MAIN = '--main' in sys.argv
ONLY_STRIP = '--strip' in sys.argv
STRIPV = next((a[8:] for a in sys.argv if a.startswith('--sview=')), None)
bpy.ops.wm.open_mainfile(filepath=f'{HERE}/bo_full.blend')
import scene, rig, props, anims   # noqa: E402

cam, floor, wall = scene.setup(res=(480, 400), samples=8 if DRAFT else 20)
arm = bpy.data.objects['BoRig']
R = rig.Rig(arm)
MOUTH = Vector((0, -.30, .368))

bag = props.tui_cheo()
for o in bag:
    props.parent_bone(o, arm, 'hips')
b3root, b3objs = props.tui_3o()
piv = bpy.data.objects.new('Tui3oPivot', None)
bpy.context.scene.collection.objects.link(piv)
piv.location = MOUTH
b3root.parent = piv
b3root.location = (0, 0, -.065)        # đỉnh quai (z = 0,065 trên miệng túi) nằm đúng miệng Bơ
props.parent_bone(piv, arm, 'head')
# Mèo bạn (Xiêm, cùng rig 22 xương) cho cảnh chuyền túi
bpy.ops.import_scene.gltf(filepath='/home/user/meo-giao-banh-mi/assets/models/skin/giong/xiem_duc.glb')
parm = next(o for o in bpy.context.selected_objects if o.type == 'ARMATURE')
pobjs = [parm] + list(parm.children_recursive)
proot = bpy.data.objects.new('BanRoot', None)
bpy.context.scene.collection.objects.link(proot)
top = parm
while top.parent:
    top = top.parent
top.parent = proot
pobjs.append(top)
PR = rig.Rig(parm, prefix='P_')
for e in PR.tgt.values():
    pass
ppiv = piv.copy(); bpy.context.scene.collection.objects.link(ppiv)
pb3 = b3root.copy(); bpy.context.scene.collection.objects.link(pb3); pb3.parent = ppiv
for o in b3objs:
    c = o.copy(); bpy.context.scene.collection.objects.link(c); c.parent = pb3
ppiv.parent = None
ppiv.matrix_world = Matrix.Translation(MOUTH)
props.parent_bone(ppiv, parm, 'head')
medal = props.huy_chuong()
for o in medal:
    props.parent_bone(o, arm, 'chest')
drops = props.giot_nuoc((0, 0, .3))
ctx = props.canh()


def show(objs, on):
    for o in objs:
        o.hide_render = not on
        for c in o.children_recursive:
            c.hide_render = not on


def place_partner(an, t):
    on = bool(an.get('partner'))
    show(pobjs + [ppiv], on)
    if not on:
        return
    pa = anims.ANIMS[an['partner']]
    proot.matrix_world = Matrix.Translation((0, -.74, 0)) @ Matrix.Rotation(math.pi, 4, 'Z')
    bpy.context.view_layer.update()
    keys = [(k, rig.full(merge_base(pa, d))) for k, d in pa['keys']]
    p = rig.sample(keys, t)
    PR.modes = {k: pa.get('modes', {}).get(k, 'w') for k in rig.LEGS}
    PR.apply(p)
    hold = p.get('bag3', (0, 0))[1] > .5
    show([pb3], hold)
    bpy.context.view_layer.update()
    pos = ppiv.matrix_world.translation.copy()
    ppiv.matrix_world = Matrix.Translation(pos) @ Matrix.Rotation(math.pi, 4, 'Z') @ Matrix.Rotation(math.radians(p['bag3'][0]), 4, 'X')


def pose_at(an, t):
    place_partner(an, t)
    keys = [(k, rig.full(merge_base(an, d))) for k, d in an['keys']]
    p = rig.sample(keys, t)
    R.modes = {k: an.get('modes', {}).get(k, 'w') for k in rig.LEGS}
    R.apply(p)
    pr = dict(an.get('props', {}))
    for k, d in an['keys']:
        pass
    pv = {k: v for k, v in p.items() if k in ('bag3', 'medal', 'drops')}
    show(bag, an.get('bag', False))
    show([b3root], an.get('bag3', False) and pv.get('bag3', (0, 1))[1] > .5)
    show(medal, pv.get('medal', (0,))[0] > .5)
    show(drops, pv.get('drops', (0,))[0] > .5)
    if an.get('bag3'):
        # túi treo thẳng theo trọng lực từ miệng, đung đưa theo khoá 'bag3'
        bpy.context.view_layer.update()
        pos = piv.matrix_world.translation.copy()
        sw = math.radians(pv.get('bag3', (0,))[0])
        piv.matrix_world = Matrix.Translation(pos) @ Matrix.Rotation(sw, 4, 'X')
    bpy.context.view_layer.update()
    return p


def merge_base(an, d):
    o = dict(an.get('base', {}))
    o.update(d)
    return o


for n in ('bag3', 'medal', 'drops'):
    pass

for o in drops + medal:
    o.hide_render = True
for objs in ctx.values():
    show(objs, False)

names = list(anims.ANIMS) if WANT == 'all' else WANT.split(',')
for name in names:
    an = anims.ANIMS[name]
    for k, objs in ctx.items():
        show(objs, an.get('ctx') == k)
    floor.location.z = {'plank': -.6, 'ledge': -.8, 'pipe': -.8}.get(an.get('ctx'), 0)
    dc, ds = {'ledge': ((0, -.2, .42), 1.45), 'pipe': ((0, -.12, .5), 1.5), 'walls': ((0, -.1, .42), 1.6),
              'plank': ((0, 0, .15), 1.2)}.get(an.get('ctx'), ((0, 0, .27), 1.0))
    cen = an.get('center', dc)
    sc = an.get('scale', ds)
    if not ONLY_MAIN:
        for i, t in enumerate(an['shots']):
            pose_at(an, t)
            scene.shoot(cam, wall, STRIPV or an.get('strip_view', 'q34r' if an.get('ctx') in ('ledge', 'pipe') else 'q34'), f'{OUT}/{name}_k{i}.png', cen, sc, res=(480, 400))
    if not ONLY_STRIP:
        pose_at(an, an['main'])
        for v in an.get('views', ('q34r', 'side', 'back', 'q34l') if an.get('ctx') in ('ledge', 'pipe') else ('q34', 'side', 'front', 'back')):
            scene.shoot(cam, wall, v, f'{OUT}/{name}_{v}.png', cen, sc, res=(640, 540))
    print('xong', name)
