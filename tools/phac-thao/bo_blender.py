"""Ráp Bơ trong Blender (chạy ngầm qua module bpy): nạp lưới SDF, thêm mắt, ria,
vật liệu, đèn, camera; render các góc và xuất .glb."""
import bpy, bmesh, numpy as np, math, sys, os
from mathutils import Vector, Euler

D = sys.argv[1]
VIEWS = sys.argv[2].split(',') if len(sys.argv) > 2 else ['q34', 'side', 'front', 'back']
SAMPLES = int(sys.argv[3]) if len(sys.argv) > 3 else 64
RES = int(sys.argv[4]) if len(sys.argv) > 4 else 1000

bpy.ops.wm.read_factory_settings(use_empty=True)
sc = bpy.context.scene

def B(p):  # three.js (x, y lên, z trước) -> Blender (x, -z, y)
    return Vector((p[0], -p[2], p[1]))

def hexc(h, a=1.0):
    h = h.lstrip('#'); c = [int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)]
    c = [x / 12.92 if x <= 0.04045 else ((x + 0.055) / 1.055) ** 2.4 for x in c]
    return (*c, a)

def make_mesh(name, V, F, C=None):
    me = bpy.data.meshes.new(name)
    Vb = np.stack([V[:, 0], -V[:, 2], V[:, 1]], 1)
    me.vertices.add(len(Vb)); me.vertices.foreach_set('co', Vb.ravel())
    me.loops.add(F.size); me.loops.foreach_set('vertex_index', F.ravel())
    me.polygons.add(len(F)); me.polygons.foreach_set('loop_start', np.arange(0, F.size, 3))
    me.update(); me.validate()
    if C is not None:
        ca = me.color_attributes.new('Col', 'FLOAT_COLOR', 'POINT')
        lin = np.where(C <= 0.04045, C / 12.92, ((C + 0.055) / 1.055) ** 2.4)
        rgba = np.concatenate([lin, np.ones((len(C), 1))], 1).astype(np.float32)
        ca.data.foreach_set('color', rgba.ravel())
        me.color_attributes.active_color = ca
    me.polygons.foreach_set('use_smooth', [True] * len(me.polygons))
    ob = bpy.data.objects.new(name, me); sc.collection.objects.link(ob)
    return ob

def principled(name, color=None, attr=None, rough=0.6, **kw):
    m = bpy.data.materials.new(name); m.use_nodes = True
    nt = m.node_tree; bs = nt.nodes['Principled BSDF']
    if attr:
        a = nt.nodes.new('ShaderNodeVertexColor'); a.layer_name = attr
        nt.links.new(a.outputs['Color'], bs.inputs['Base Color'])
    else:
        bs.inputs['Base Color'].default_value = hexc(color)
    bs.inputs['Roughness'].default_value = rough
    for k, val in kw.items():
        bs.inputs[k].default_value = val
    return m, nt, bs

def add_bump(nt, bs, scale, strength, kind='noise'):
    tc = nt.nodes.new('ShaderNodeTexCoord')
    if kind == 'noise':
        t = nt.nodes.new('ShaderNodeTexNoise'); t.inputs['Scale'].default_value = scale; t.inputs['Detail'].default_value = 8
    else:
        t = nt.nodes.new('ShaderNodeTexWave'); t.inputs['Scale'].default_value = scale; t.wave_type = 'BANDS'; t.bands_direction = 'Z'
    nt.links.new(tc.outputs['Object'], t.inputs['Vector'])
    b = nt.nodes.new('ShaderNodeBump'); b.inputs['Strength'].default_value = strength; b.inputs['Distance'].default_value = 0.002
    nt.links.new(t.outputs['Fac'], b.inputs['Height']); nt.links.new(b.outputs['Normal'], bs.inputs['Normal'])

def smooth(ob, f=0.5, it=4):
    md = ob.modifiers.new('Smooth', 'SMOOTH'); md.factor = f; md.iterations = it

# ---------- thân ----------
bd = np.load(f'{D}/bo_body.npz')
body = make_mesh('Bo_Than', bd['v'], bd['f'], bd['c'])
smooth(body, 0.5, 6)
mfur, nt, bs = principled('Long_Bo', attr='Col', rough=0.88)
bs.inputs['Sheen Weight'].default_value = 0.2
bs.inputs['Sheen Roughness'].default_value = 0.4
bs.inputs['Subsurface Weight'].default_value = 0.12
bs.inputs['Subsurface Scale'].default_value = 0.01
add_bump(nt, bs, 900, 0.12)
body.data.materials.append(mfur)

# ---------- khăn ----------
sd = np.load(f'{D}/bo_scarf.npz')
scarf = make_mesh('Bo_Khan', sd['v'], sd['f'])
smooth(scarf, 0.5, 4)
mred, nt, bs = principled('Vai_Khan', '#C8412F', rough=0.85)
bs.inputs['Sheen Weight'].default_value = 0.6
add_bump(nt, bs, 160, 0.25, 'wave')
scarf.data.materials.append(mred)

# ---------- mắt ----------
def eye(side):
    c = B((side * 0.056, 0.437, 0.301))
    bpy.ops.mesh.primitive_uv_sphere_add(segments=48, ring_count=32, radius=0.031, location=c)
    ob = bpy.context.active_object; ob.name = f'Bo_Mat_{"T" if side < 0 else "P"}'
    ob.scale = (1, 0.8, 1.08)
    ob.rotation_euler = Euler((0, 0, side * 0.38))   # nhìn hơi chếch ra ngoài
    me = ob.data
    # màu theo hướng: tròng nâu hổ phách, con ngươi khe dọc
    ca = me.color_attributes.new('Col', 'FLOAT_COLOR', 'POINT')
    cols = []
    for vt in me.vertices:
        p = vt.co.normalized()  # local; trước = -Y
        fwd = -p.y
        r = math.hypot(p.x, p.z)
        if fwd < 0.2:
            cc = hexc('#F3EEE4')
        elif abs(p.x) < 0.11 * (1 - (p.z / 0.75) ** 2) and fwd > 0.6 and abs(p.z) < 0.75:
            cc = hexc('#0E0B09')
        else:
            t = min(1, max(0, (r - 0.2) / 0.7))
            a, b_ = hexc('#B07A2E'), hexc('#5A3A1E')
            cc = tuple(a[i] * (1 - t) + b_[i] * t for i in range(3)) + (1,)
            if fwd < 0.32: cc = hexc('#2A1A0E')
        cols.extend(cc)
    ca.data.foreach_set('color', cols)
    m, nt2, b2 = principled('Mat', attr='Col', rough=0.05)
    b2.inputs['Coat Weight'].default_value = 1.0; b2.inputs['Coat Roughness'].default_value = 0.02
    me.materials.append(m)
    bpy.ops.object.shade_smooth()
    return ob
eye(-1); eye(1)

# ---------- ria ----------
mwh, _, _ = principled('Ria', '#F4EEE2', rough=0.4)
for side in (-1, 1):
    for i, (dy, ang) in enumerate([(0.008, 0.18), (0.0, 0.0), (-0.009, -0.16)]):
        cu = bpy.data.curves.new(f'ria{side}{i}', 'CURVE'); cu.dimensions = '3D'
        cu.bevel_depth = 0.0007; cu.bevel_resolution = 2
        sp = cu.splines.new('BEZIER'); sp.bezier_points.add(1)
        a = (side * 0.035, 0.378 + dy, 0.33); bpt = (side * 0.15, 0.378 + dy + ang * 0.1 + 0.01, 0.30 - 0.03)
        for k, p in enumerate([a, bpt]):
            bp = sp.bezier_points[k]; bp.co = B(p); bp.handle_left_type = bp.handle_right_type = 'AUTO'
        sp.bezier_points[1].co.z += 0.004
        ob = bpy.data.objects.new(f'Bo_Ria', cu); sc.collection.objects.link(ob); cu.materials.append(mwh)
        # thuôn đầu ria
        sp.bezier_points[1].radius = 0.2

# ---------- sàn, nền, đèn ----------
bpy.ops.mesh.primitive_plane_add(size=40, location=(0, 0, 0))
floor = bpy.context.active_object
mf, _, bsf = principled('San', '#3A4746', rough=0.9)
floor.data.materials.append(mf)
w = bpy.data.worlds.new('W'); sc.world = w; w.use_nodes = True
w.node_tree.nodes['Background'].inputs['Color'].default_value = hexc('#2B3535')
w.node_tree.nodes['Background'].inputs['Strength'].default_value = 0.6

def area(name, loc, target, size, power, color='#FFFFFF'):
    l = bpy.data.lights.new(name, 'AREA'); l.size = size; l.energy = power; l.color = hexc(color)[:3]
    o = bpy.data.objects.new(name, l); sc.collection.objects.link(o); o.location = loc
    d = Vector(target) - Vector(loc); o.rotation_euler = d.to_track_quat('-Z', 'Y').to_euler()
    return o
T = (0, 0, 0.3)
area('Key', (1.2, -1.4, 1.5), T, 1.2, 160, '#FFF8F0')
area('Fill', (-1.6, -0.6, 0.8), T, 1.8, 60, '#DDE8FF')
area('Rim', (-0.4, 1.6, 1.3), T, 1.0, 150, '#FFFFFF')

sc.render.engine = 'CYCLES'
sc.cycles.device = 'CPU'
sc.cycles.samples = SAMPLES
sc.cycles.use_denoising = True
sc.render.resolution_x = RES; sc.render.resolution_y = int(RES * 0.8)
sc.view_settings.view_transform = 'Standard'
sc.view_settings.exposure = -0.3

cam_d = bpy.data.cameras.new('Cam'); cam = bpy.data.objects.new('Cam', cam_d); sc.collection.objects.link(cam); sc.camera = cam
VIEWDEF = {
    'q34':   dict(loc=(0.95, -1.15, 0.62), ortho=None, lens=70),
    'side':  dict(loc=(1.6, 0.0, 0.33), ortho=0.95),
    'front': dict(loc=(0.0, -1.6, 0.33), ortho=0.95),
    'back':  dict(loc=(0.0, 1.6, 0.33), ortho=0.95),
    'face':  dict(loc=(0.35, -0.9, 0.48), ortho=None, lens=110, tgt=(0, -0.24, 0.41)),
    'top':   dict(loc=(0.0, -0.02, 1.8), ortho=1.0),
}
for vn in [x for x in VIEWS if x]:
    vd = VIEWDEF[vn]
    tgt = Vector(vd.get('tgt', (0, 0.03, 0.31)))
    cam.location = vd['loc']
    cam.rotation_euler = (tgt - cam.location).to_track_quat('-Z', 'Y').to_euler()
    if vd['ortho']:
        cam_d.type = 'ORTHO'; cam_d.ortho_scale = vd['ortho']
    else:
        cam_d.type = 'PERSP'; cam_d.lens = vd['lens']
    sc.render.filepath = f'{D}/bo_{vn}.png'
    bpy.ops.render.render(write_still=True)
    print('rendered', vn)

if '--glb' in sys.argv:
    floor.hide_set(True)
    for ob in list(sc.objects):
        ob.select_set(ob.type in ('MESH', 'CURVE') and ob is not floor)
    # giảm tam giác cho bản xem trên web
    for ob in (body, scarf):
        md = ob.modifiers.new('Dec', 'DECIMATE'); md.ratio = 0.4
    bpy.ops.export_scene.gltf(filepath=(f'{D}/bo_sdf.gltf' if '--embed' in sys.argv else f'{D}/bo_sdf.glb'),
                              **({'export_format': 'GLTF_EMBEDDED'} if '--embed' in sys.argv else {}), use_selection=True, export_apply=True,
                              export_vertex_color='ACTIVE', export_yup=True)
    bpy.ops.wm.save_as_mainfile(filepath=f'{D}/bo_sdf.blend')
    print('glb done')
