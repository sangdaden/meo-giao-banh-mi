"""Ảnh so cỡ (8 mèo hội + Bơ đứng hàng trên lưới mét) và ảnh cảnh dùng (tối Hội mèo, đèn lồng, sân khấu thùng gỗ tạm).
Chạy: python3 canh_hoi.py <skin_dir> <out> [hang|canh|all] [--draft]"""
import sys, os, math, random
import bpy
from mathutils import Vector, Matrix

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, '/home/user/meo-giao-banh-mi/tools/dong_tac_bo'); sys.path.insert(0, HERE)
SKIN, OUT = sys.argv[1], sys.argv[2]
WHAT = sys.argv[3] if len(sys.argv) > 3 and not sys.argv[3].startswith('--') else 'all'
DRAFT = '--draft' in sys.argv
os.makedirs(OUT, exist_ok=True)
REPO = '/home/user/meo-giao-banh-mi'


def fresh():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def no_subsurf():
    # nhiều mèo cùng khung: bỏ chia lưới (Eevee hết bộ nhớ khi 9 con cùng chia)
    for o in bpy.data.objects:
        for m in list(o.modifiers):
            if m.type == 'SUBSURF':
                o.modifiers.remove(m)


def load_bo():
    import nap
    b4 = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=f'{REPO}/assets/models/bo.glb')
    new = [o for o in bpy.data.objects if o not in b4]
    nap.render_look([o for o in new if o.type == 'MESH'])
    arm = next(o for o in new if o.type == 'ARMATURE')
    top = arm
    while top.parent:
        top = top.parent
    return top, arm


def root_of(arm):
    top = arm
    while top.parent:
        top = top.parent
    return top


def pose(arm, an_name, t, prefix):
    import rig, anims_hoi as AH, anims as A2
    an = AH.ANIMS.get(an_name) or A2.ANIMS[an_name]
    R = rig.Rig(arm, prefix=prefix)
    keys = [(k, rig.full(dict(an.get('base', {}), **d))) for k, d in an['keys']]
    R.modes = {k: an.get('modes', {}).get(k, 'w') for k in rig.LEGS}
    R.apply(rig.sample(keys, t))


if WHAT in ('hang', 'all'):
    fresh()
    import scene, nap, hoi
    nap.init(SKIN)
    cam, floor, wall = scene.setup(res=(1800, 620), samples=8 if DRAFT else 32)
    order = ['bo'] + hoi.ORDER
    x0 = -(len(order) - 1) * .56 / 2
    for i, cid in enumerate(order):
        if cid == 'bo':
            top, arm = load_bo()
        else:
            arm, objs = nap.load_cat(cid)
            top = root_of(arm)
        top.location.x += x0 + i * .56
        bpy.context.view_layer.update()
    no_subsurf()
    for vw, loc, ortho in (('truoc', (0, -6, .35), 5.4), ('q34', (2.6, -5.2, 1.6), None)):
        cam.location = Vector(loc)
        tgt = Vector((0, 0, .3))
        cam.rotation_euler = (tgt - cam.location).to_track_quat('-Z', 'Y').to_euler()
        if ortho:
            cam.data.type = 'ORTHO'; cam.data.ortho_scale = ortho
        else:
            cam.data.type = 'PERSP'; cam.data.lens = 50
        wall.location = (0, 1.2, 0); wall.rotation_euler = (math.pi / 2, 0, 0)
        bpy.context.scene.render.filepath = f'{OUT}/hang_{vw}.png'
        bpy.ops.render.render(write_still=True)
    print('xong hang', flush=True)

if WHAT in ('canh', 'all'):
    fresh()
    import scene, nap, hoi, props
    nap.init(SKIN)
    sc = bpy.context.scene
    cam, floor, wall = scene.setup(res=(1280, 720), samples=8 if DRAFT else 48)
    wall.hide_render = True
    for o in list(sc.objects):
        if o.type == 'LIGHT':
            bpy.data.objects.remove(o)
    floor.data.materials.clear(); floor.data.materials.append(scene.mat('Gach', '#8E7C6A', rough=.95))
    sc.world.node_tree.nodes['Background'].inputs['Color'].default_value = scene.lin('#1E2A44')
    sc.world.node_tree.nodes['Background'].inputs['Strength'].default_value = .5

    def light(kind, loc, power, color, size=.3, tgt=None):
        l = bpy.data.lights.new('L', kind); l.energy = power; l.color = color
        if kind == 'AREA': l.size = size
        if kind in ('POINT', 'SPOT'): l.shadow_soft_size = size
        o = bpy.data.objects.new('L', l); sc.collection.objects.link(o); o.location = loc
        if tgt: o.rotation_euler = (Vector(tgt) - Vector(loc)).to_track_quat('-Z', 'Y').to_euler()
        return o
    light('SUN', (2, -3, 4), .35, (.6, .7, 1.0), tgt=(0, 0, 0))
    light('AREA', (0, -2.2, 1.6), 140, (1, .78, .5), 2.5, (0, 0, .3))
    # dây đèn lồng tạm (đèn thật thuộc G11): 2 dây võng qua sân
    red = scene.mat('LongDo', '#D8442E', rough=.6, emit=3.0); yel = scene.mat('LongVang', '#F2B53A', rough=.6, emit=3.0)
    cord = scene.mat('Day', '#3A2A20')
    random.seed(4)
    for row, (y, z0) in enumerate(((.9, 1.9), (-.2, 2.1))):
        for i in range(11):
            u = i / 10; x = -2.4 + 4.8 * u; z = z0 - .35 * math.sin(u * math.pi)
            bpy.ops.mesh.primitive_uv_sphere_add(segments=16, ring_count=10, radius=.085, location=(x, y, z))
            o = bpy.context.active_object; o.scale = (1, 1, 1.25); o.data.materials.append(red if (i + row) % 2 else yel)
            if i % 3 == 1:
                light('POINT', (x, y, z - .05), 18, (1, .62, .32), .1)
    cr = props.rbox('ThungSanKhau', (.62, .46, .4), (0, .55, .2), scene.mat('GoTam', '#A9805A', rough=.85), .012, 2)
    cats = [('ba_muop', (0, .52, .4), math.pi, 'ngoi_san_khau', .75),
            ('tuyet', (-.9, .2, 0), math.pi * .92, 'ngoi_xem', .75), ('lac', (-.45, .05, 0), math.pi * .96, 'vay_duoi', .25),
            ('sua', (.55, .05, 0), math.pi * 1.06, 'ngoi_xem', 1.65), ('gung', (1.0, .25, 0), math.pi * 1.1, 'vay_duoi', .125),
            ('mit', (-1.45, .55, 0), math.pi * .85, 'ngoi_xem', 2.25), ('bot', (1.5, .6, 0), math.pi * 1.18, 'ngoi_xem', 0),
            ('mun', (-1.9, 1.1, 0), math.pi * .8, 'lo_dau', .75)]
    for i, (cid, loc, rz, an, t) in enumerate(cats):
        arm, objs = nap.load_cat(cid)
        top = root_of(arm)
        if cid != 'ba_muop':   # khán giả quay mặt về sân khấu (mèo nhìn -Y khi rz = 0)
            dx, dy = -loc[0], .55 - loc[1]; rz = math.atan2(dx, -dy) + random.uniform(-.25, .25)
        else:
            rz = .15
        top.rotation_mode = 'XYZ'; top.location = loc; top.rotation_euler = (0, 0, rz)
        bpy.context.view_layer.update()
        pose(arm, an, t, f'{cid}_')
    top, arm = load_bo()
    top.rotation_mode = 'XYZ'; top.location = (.15, -.55, 0); top.rotation_euler = (0, 0, math.atan2(-.15, -1.1))
    bpy.context.view_layer.update()
    pose(arm, 'ngoi_xem', 1.2, 'bo_')
    no_subsurf()
    cam.location = Vector((1.1, -3.3, .95)); cam.data.type = 'PERSP'; cam.data.lens = 28
    cam.rotation_euler = (Vector((0, .3, .62)) - cam.location).to_track_quat('-Z', 'Y').to_euler()
    sc.render.filepath = f'{OUT}/canh_hoi.png'
    bpy.ops.render.render(write_still=True)
    print('xong canh', flush=True)
